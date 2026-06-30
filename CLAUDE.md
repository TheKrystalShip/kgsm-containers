# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`kgsm-containers` ships **standardized container images for KGSM-compatible game servers**. Images are built in **two layers**: one shared base (`kgsm-base`) and one image per game that derives `FROM kgsm-base:<version>`. Part of the KGSM ecosystem (see `../tks/system-architecture.md`); the containers are a peer to native instances, not a leaf service.

## Layout

```
images/
├── base/                      # the shared foundation — build FIRST
│   ├── Dockerfile             # FROM steamcmd/steamcmd:debian + tini + toolchain + shim
│   ├── entrypoint-base.sh     # tini → this → starts shim, exec's the game CMD
│   ├── kgsm-presence-shim.sh  # additive log-tailer → NDJSON player events
│   └── build.sh               # builds + tags kgsm-base:<version> and :latest
├── <game>/                    # one dir per game: Dockerfile + build.sh + manage script
└── build_all.sh               # base, then every game
templates/                     # Dockerfile + build.sh + manage-script skeleton for a new game
```

## Build & validate

```sh
cd images && ./build_all.sh          # everything (base first); --push to publish
cd images/base && ./build.sh         # just the base
```
There are no unit tests; validation is a `docker build` plus a container smoke. To exercise the shim: run a game (or the base) with `KGSM_PLAYER_{JOINED,LEFT}_REGEX_B64` set and `/run/kgsm` bind-mounted, feed the game log matching lines, and assert the host-side `events.ndjson`.

## Architecture invariants (do not break these)

1. **Games pin the base version.** Every game Dockerfile uses `FROM kgsm-base:<version>` — **never** bare `FROM kgsm-base`. This stops a base rebuild from silently changing games.
2. **Version is single-sourced + bumped in lockstep.** `version="…"` lives once in `images/base/build.sh`. To move games to a new base, change that **and** the `FROM kgsm-base:<v>` line in **every** game Dockerfile, together — never one without the other.
3. **Common setup lives only in `kgsm-base`.** The `kgsm` user, `tini`, the Wine/xvfb/locales/steamcmd toolchain, `/tmp/.X11-unix`, `/run/kgsm`, and the shim are all in the base. Game Dockerfiles add **only** game-specific dependencies + the game's dirs/script.
4. **Games set `CMD`, never `ENTRYPOINT`.** The base owns the ENTRYPOINT (`tini → entrypoint-base.sh`). A game's `CMD` is its launch command (the old `ENTRYPOINT`+`CMD`), which the base wrapper runs verbatim.
5. **The shim is additive.** It runs alongside the game and only *reads* the game log. Never reroute the game's stdout, and never touch the per-game `manage.sh` launch or its **stdin-FIFO stop/save** path.
6. **Never fabricate presence.** No regex env → detection disabled, zero events. A match that captures neither id nor name is skipped, never emitted as `{null,null}`. (Mirrors the ecosystem honesty rule: measured or unknown, never invented.)

## Player-presence contract

- **In (env, set by KGSM from the blueprint):** `KGSM_PLAYER_JOINED_REGEX_B64` / `KGSM_PLAYER_LEFT_REGEX_B64` — base64-encoded **Perl** regexes with optional named groups `(?<id>…)` / `(?<name>…)`. Empty/unset disables that detection.
- **Out:** append-only NDJSON at `/run/kgsm/events.ndjson`, fresh inode per container start:
  ```json
  {"type":"player_joined"|"player_left","id":<str|null>,"name":<str|null>,"ts":"<ISO-8601-UTC>"}
  ```
- **Why base64:** raw regexes carry `$ < > \ "` etc.; passing them through compose-YAML → shell → container mangles them. Encode at the source, decode in the shim.
- **Cross-repo:** the host bind-mounts `/run/kgsm` to a per-instance dir; **`kgsm-watchdog`** tails `events.ndjson` and emits `instance-player-joined/-left` engine events (`system/system`). KGSM (bash) injects the bind-mount + env from the game's blueprint `container.compose`. Full design: `../tks/player-presence-plan.md`.

## Conventions

- Each game Dockerfile keeps an attribution header, `LABEL org.opencontainers.image.{source,authors}`, `EXPOSE`, game ENV (`SERVER_HOME`, `MANAGEMENT_FILE`), the dirs `RUN`, game-apt `RUN`, `COPY` the script, `WORKDIR`, `USER ${USER}`, `CMD`.
- Bash scripts: keep `shellcheck`-clean. The shim depends only on tools present in the base (`bash`, `perl`, `tail`, `base64`) — no new apt deps for shim work.

## Known gaps

- Per-game **runtime** smoke (boot a real server from each image) is owed — current validation is `docker build` + the shim container e2e, not a full game boot.

## Version tracking

- **Version source:** `version=` variable in `images/base/build.sh`; bump it when the base image changes, then update `FROM kgsm-base:<version>` in every game Dockerfile
- Bump the version whenever you make a user-facing change (new feature, bug fix, behaviour change). Patch for fixes, minor for new features, major for breaking changes.
- Update `CHANGELOG.md` under `## [Unreleased]` with a brief entry for every meaningful change.
- A git tag matching the new version should be created on release: `git tag v<version>`.
