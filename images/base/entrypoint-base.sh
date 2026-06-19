#!/usr/bin/env bash

# KGSM base entrypoint
#
# tini (PID 1) exec's this, and this exec's the per-game launch command. Its job
# is purely additive:
#   1. Start the player-presence shim in the background (it tails the game log
#      and self-reports join/left events; see kgsm-presence-shim.sh).
#   2. Launch the per-game command ("$@", supplied as the image CMD) with its
#      stdout/stderr tee'd into a container-internal log file the shim reads —
#      output still reaches stdout, so `docker compose up` / docker logs and the
#      host-side KGSM log capture are unaffected.
#
# This does NOT touch the per-game management script, its launch path, or its
# stdin-FIFO stop/save mechanism — those run exactly as before, unmodified.
#
# Author: Cristian Moraru <cristian.moraru@live.com>
# Version: 1.0
#
# Copyright (c) 2025 The Krystal Ship
# Licensed under the GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html

set -o pipefail

export KGSM_EVENTS_DIR="${KGSM_EVENTS_DIR:-/run/kgsm}"
export KGSM_GAME_LOG="${KGSM_GAME_LOG:-$KGSM_EVENTS_DIR/game.log}"

SHIM="${KGSM_PRESENCE_SHIM:-/opt/kgsm/kgsm-presence-shim.sh}"

# Best-effort: ensure the channel dir exists and start fresh. The shim also does
# this; doing it here too means the game-log tee target is ready immediately.
mkdir -p "$KGSM_EVENTS_DIR" 2>/dev/null || true
: >"$KGSM_GAME_LOG" 2>/dev/null || true

# Start the presence shim alongside the game. It is intentionally non-fatal:
# a shim failure must never take down the game server.
if [[ -x "$SHIM" ]]; then
  "$SHIM" &
else
  echo "[kgsm-entrypoint] presence shim not found/executable at $SHIM; skipping" >&2
fi

# Launch the per-game command. tee duplicates output to the game log the shim
# reads while preserving stdout for docker logs. `exec` keeps tini -> game as a
# clean signal-forwarding chain (the tee runs as a child of the same shell).
if [[ "$#" -eq 0 ]]; then
  echo "[kgsm-entrypoint] no command given; nothing to launch" >&2
  exit 1
fi

exec "$@" > >(tee -a "$KGSM_GAME_LOG") 2>&1
