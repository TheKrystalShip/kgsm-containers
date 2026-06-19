#!/usr/bin/env bash

# KGSM player-presence detection shim
#
# Additive background tailer that watches the game's log file and self-reports
# player join/left events to the host over an append-only NDJSON channel.
# Started by the base entrypoint *alongside* the per-game launch; it never
# touches the game's stdout, launch path, or stdin-FIFO stop/save mechanism.
#
# Contract (player-presence-plan.md, schema B / env C):
#   - Reads KGSM_PLAYER_JOINED_REGEX_B64 / KGSM_PLAYER_LEFT_REGEX_B64, each a
#     base64-encoded regex with optional named groups (?<id>...) / (?<name>...).
#     Empty/unset -> that detection is disabled (no events).
#   - On each match, appends one NDJSON line to /run/kgsm/events.ndjson:
#       {"type":"player_joined"|"player_left","id":<str|null>,"name":<str|null>,"ts":"<ISO-8601-UTC>"}
#   - Creates a FRESH file (new inode) on container start; never truncates in
#     place (the watchdog keys on inode).
#   - Enforces at-least-one-non-null: a match capturing neither id nor name is
#     skipped + logged, never emitted as {null,null}.
#
# Author: Cristian Moraru <cristian.moraru@live.com>
# Version: 1.0
#
# Copyright (c) 2025 The Krystal Ship
# Licensed under the GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html

set -o pipefail

# In-container event channel (host bind-mounts ${instance_events_file} here).
KGSM_EVENTS_DIR="${KGSM_EVENTS_DIR:-/run/kgsm}"
KGSM_EVENTS_FILE="${KGSM_EVENTS_FILE:-$KGSM_EVENTS_DIR/events.ndjson}"

# Log file the base entrypoint tee's the game output into (container-internal
# scratch path, NOT the bind-mounted logs dir — the host already captures
# `docker compose up` stdout separately).
KGSM_GAME_LOG="${KGSM_GAME_LOG:-$KGSM_EVENTS_DIR/game.log}"

function __log() {
  echo "[kgsm-presence-shim] $1" >&2
}

# Decode a base64 env var into a regex, tolerating empty/unset.
# Echoes the decoded value (empty if the source was empty/unset/undecodable).
function __decode_b64() {
  local encoded="$1"
  [[ -z "$encoded" ]] && return 0
  # `base64 -d` is GNU coreutils (present on Debian); -w0 not needed for decode.
  printf '%s' "$encoded" | base64 -d 2>/dev/null
}

# Create a fresh-inode events file on every start. We unlink any prior file
# (e.g. a leftover from an earlier container with the same mount) and create a
# new one so the watchdog sees a new inode and re-reads from offset 0.
function __init_events_file() {
  mkdir -p "$KGSM_EVENTS_DIR" 2>/dev/null
  # Unlink (not truncate) so a brand-new inode is allocated.
  rm -f "$KGSM_EVENTS_FILE" 2>/dev/null
  if ! : >"$KGSM_EVENTS_FILE"; then
    __log "FATAL: cannot create events file $KGSM_EVENTS_FILE — presence disabled"
    return 1
  fi
  return 0
}

# The perl matcher program (single-quoted heredoc so bash does not touch
# $+{}, backslashes, or sigils). Reads stdin line by line, matches each line
# against the joined/left regexes supplied via env, and appends NDJSON to the
# events file. Long-lived: one perl process for the whole container lifetime.
read -r -d '' KGSM_MATCHER_PL <<'PERL_EOF'
use strict;
use warnings;

my $joined_re_src = $ENV{KGSM_JOINED_RE} // '';
my $left_re_src   = $ENV{KGSM_LEFT_RE}   // '';
my $events_file   = $ENV{KGSM_EVENTS_FILE};

# Pre-compile the patterns that are present. An invalid pattern disables that
# detection (logged once) rather than killing the shim.
my ($joined_re, $left_re);
if (length $joined_re_src) {
  $joined_re = eval { qr/$joined_re_src/ };
  warn "[kgsm-presence-shim] invalid player_joined_regex, join detection disabled\n" unless $joined_re;
}
if (length $left_re_src) {
  $left_re = eval { qr/$left_re_src/ };
  warn "[kgsm-presence-shim] invalid player_left_regex, left detection disabled\n" unless $left_re;
}

# JSON string-escape a captured value, or the literal token `null` when absent.
sub json_field {
  my ($v) = @_;
  return 'null' unless defined $v;
  $v =~ s/\\/\\\\/g;
  $v =~ s/"/\\"/g;
  $v =~ s/\x08/\\b/g;
  $v =~ s/\f/\\f/g;
  $v =~ s/\n/\\n/g;
  $v =~ s/\r/\\r/g;
  $v =~ s/\t/\\t/g;
  $v =~ s/([\x00-\x1f])/sprintf("\\u%04x", ord($1))/ge;
  return '"' . $v . '"';
}

sub iso_utc {
  my @t = gmtime;
  # Build ISO-8601-UTC from core builtins only (no POSIX.pm dep).
  return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
                 $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
}

sub emit {
  my ($type, $id, $name) = @_;
  # At-least-one-non-null: skip + log a match that captured nothing usable.
  if (!defined($id) && !defined($name)) {
    warn "[kgsm-presence-shim] $type match captured neither id nor name; skipping\n";
    return;
  }
  my $line = sprintf('{"type":"%s","id":%s,"name":%s,"ts":"%s"}',
                     $type, json_field($id), json_field($name), iso_utc());
  if (open(my $fh, '>>', $events_file)) {
    print {$fh} $line, "\n";
    close($fh);
  } else {
    warn "[kgsm-presence-shim] cannot append to $events_file: $!\n";
  }
}

$| = 1;
while (my $line = <STDIN>) {
  chomp $line;
  if ($joined_re && $line =~ $joined_re) {
    emit('player_joined', $+{id}, $+{name});
    next;
  }
  if ($left_re && $line =~ $left_re) {
    emit('player_left', $+{id}, $+{name});
    next;
  }
}
PERL_EOF

function main() {
  local joined_re left_re
  joined_re="$(__decode_b64 "${KGSM_PLAYER_JOINED_REGEX_B64:-}")"
  left_re="$(__decode_b64 "${KGSM_PLAYER_LEFT_REGEX_B64:-}")"

  # Nothing to detect — stay out of the way entirely (honest unknown, no events).
  if [[ -z "$joined_re" && -z "$left_re" ]]; then
    __log "no join/left patterns configured — presence detection disabled"
    return 0
  fi

  if ! __init_events_file; then
    return 1
  fi

  if ! command -v perl >/dev/null 2>&1; then
    __log "FATAL: perl not found — presence detection disabled"
    return 1
  fi

  __log "watching $KGSM_GAME_LOG -> $KGSM_EVENTS_FILE"

  # Wait for the game log to appear (the base entrypoint truncates/creates it
  # before launching the game, so this is normally immediate).
  while [[ ! -e "$KGSM_GAME_LOG" ]]; do
    sleep 1
  done

  # Export the matcher's inputs so the perl process (the right-hand side of the
  # pipe) inherits them — a `VAR=x cmd` prefix would only reach `tail`.
  export KGSM_JOINED_RE="$joined_re"
  export KGSM_LEFT_RE="$left_re"
  export KGSM_EVENTS_FILE
  # Read from offset 0 then follow (`-n +1`), not `-n0`: the entrypoint
  # truncates the log once at container start and the shim runs once per
  # container, so reading from the start can neither miss a boot-time line
  # (the `-n0` startup race) nor double-read. `-F` follows across rotation.
  tail -n +1 -F "$KGSM_GAME_LOG" 2>/dev/null | perl -e "$KGSM_MATCHER_PL"
}

main "$@"
