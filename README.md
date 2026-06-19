# KGSM-Containers

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

> Standardized container images for game servers with KGSM compatibility

## Table of Contents
- [Overview](#overview)
- [Supported Games](#-supported-games)
- [Getting Started](#-getting-started)
- [Image Architecture](#-image-architecture)
- [Building the Images](#-building-the-images)
- [Player-Presence Detection](#-player-presence-detection)
- [Adding a New Game Image](#-adding-a-new-game-image)
- [Contributing](#-contributing)
- [License](#-license)

## Overview

KGSM-Containers provides standardized Docker container images for game servers that work seamlessly with [KGSM (Krystal Game Server Manager)](https://github.com/TheKrystalShip/KGSM). While designed for KGSM integration, these containers can also be used independently.

All game images derive from a single shared base image, **`kgsm-base`**, which carries the common toolchain, a non-root user, an init process, and an additive player-presence detector. Each game image adds only its game-specific dependencies and launch command.

## 🎲 Supported Games

| Game | Image |
|---|---|
| V Rising | `vrising` |
| Enshrouded | `enshrouded` |
| The Forest | `theforest` |
| Empyrion: Galactic Survival | `empyrion` |
| Abiotic Factor | `abioticfactor` |
| The Lord of the Rings: Return to Moria | `lotrrtm` |

> [!NOTE]
> New game server images are added regularly. Contributions welcome — see [Adding a New Game Image](#-adding-a-new-game-image).

## 🚀 Getting Started

### Prerequisites

- Docker installed and running
- Basic knowledge of Docker commands

### With KGSM (Recommended)

> [!NOTE]
> Container-based instances are available with KGSM v2.0+.

```sh
# Create a container-based game server
kgsm --create vrising --name myserver
```

KGSM wires up the volumes, ports, and (optionally) player-presence detection for you. See the [KGSM repository](https://github.com/TheKrystalShip/KGSM).

### Standalone Docker

```sh
docker run -it \
  --name vrising-server \
  -p 9876:9876/udp \
  -p 9877:9877/udp \
  -v vrising-backups:/opt/vrising/backups \
  -v vrising-install:/opt/vrising/install \
  -v vrising-logs:/opt/vrising/logs \
  -v vrising-saves:/opt/vrising/saves \
  -v vrising-temp:/opt/vrising/temp \
  ghcr.io/thekrystalship/vrising:latest
```

Player-presence detection stays **off** unless you provide its env (see [Player-Presence Detection](#-player-presence-detection)).

## 📦 Image Architecture

Images are built in **two layers**: the shared `kgsm-base`, and one image per game `FROM kgsm-base:<version>`.

### The `kgsm-base` image

A single foundation that every game image derives from. It contains:

- **Base OS:** Debian 13 (trixie), via `steamcmd/steamcmd:debian` (SteamCMD preinstalled at `/usr/bin/steamcmd`).
- **`tini`** as PID 1 — clean signal forwarding so `docker stop` shuts the game down gracefully.
- **Common game toolchain:** Wine (`wine64`), `xvfb` (virtual display), and `locales` (`en_US.UTF-8`), with i386 enabled.
- A non-root **`kgsm`** user (home `/home/kgsm`).
- **`/run/kgsm`** — the in-container event channel directory (owned by `kgsm`).
- **`/opt/kgsm/`** — `entrypoint-base.sh` (the wrapper) and `kgsm-presence-shim.sh` (the detector).

It sets the `tini` **ENTRYPOINT** and **no CMD** — each game supplies its own `CMD`.

### Startup chain

```
tini (PID 1)
  └─ /opt/kgsm/entrypoint-base.sh
       ├─ starts kgsm-presence-shim.sh in the background (non-fatal)
       └─ exec <game CMD>  ── stdout tee'd to /run/kgsm/game.log (the shim reads it)
```

The game's `CMD` is the per-game launch command — the same command that used to be the game's `ENTRYPOINT`. The base wrapper is **purely additive**: the game's stdout still reaches `docker logs`, and the per-game management script (including its stdin-FIFO stop/save path) runs unchanged.

### Per-game image

Each game image adds only what is specific to that game: extra dependencies, its server directories, its management/launch script, `EXPOSE`d ports, `USER kgsm`, and a `CMD`. The shared user, toolchain, X11 setup, locale, init, and presence shim all come from `kgsm-base`.

### Directory structure (inside a game image)

```
/opt/<game>/
├── backups/   # automated or manual backups
├── install/   # game server installation files
├── logs/      # server log files
├── saves/     # game save files
├── temp/      # temporary files
└── <game>.manage.sh   # management / launch script (the image CMD)
```

## 🔨 Building the Images

```sh
cd images
./build_all.sh            # base first, then every game (add --push to publish)
# or individually:
cd base && ./build.sh     # the base — build this before any game
cd ../vrising && ./build.sh
```

### Version pinning (why a base change can't break games)

Game images pin a **specific** base tag — `FROM kgsm-base:1.0` — never the floating `kgsm-base` / `:latest`. The version is defined **once**, in `images/base/build.sh`:

```sh
version="1.0"   # base/build.sh — tags kgsm-base:1.0 and kgsm-base:latest
```

So rebuilding (or changing) the base produces a new `kgsm-base:latest`, but every game keeps sitting on the exact `:1.0` it pinned until you deliberately move it.

### Bumping the base (lockstep)

A base bump is **intentional and explicit** — change both, together:

1. `version="…"` in `images/base/build.sh`, and
2. the `FROM kgsm-base:<version>` line in **every** game Dockerfile.

Then rebuild the base, then the games. Skipping either half is the failure mode the pin exists to prevent.

### Rebuilding / portability

The full recipe (`Dockerfile`, `entrypoint-base.sh`, `kgsm-presence-shim.sh`, `build.sh`) lives in `images/base/` and is committed to git, so `./images/base/build.sh` reproduces the base.

- It is **not bit-reproducible**: the `steamcmd/steamcmd:debian` tag and the apt package versions float. Pin the base by `@sha256:` digest and pin apt versions if you need exact reproducibility.
- For a portable / offline copy, export the built image:
  ```sh
  docker save kgsm-base:1.0 -o kgsm-base-1.0.tar   # later: docker load -i kgsm-base-1.0.tar
  ```

## 👥 Player-Presence Detection

Every image ships an **additive** shim (`/opt/kgsm/kgsm-presence-shim.sh`) that tails the game's log and self-reports player **join**/**leave** events as NDJSON to `/run/kgsm/events.ndjson`. The host bind-mounts that directory; KGSM's watchdog reads the file and turns the lines into engine events.

### Opt-in via env (set by KGSM from the game's blueprint)

| Env var | Meaning |
|---|---|
| `KGSM_PLAYER_JOINED_REGEX_B64` | base64-encoded regex matching a "player joined" log line |
| `KGSM_PLAYER_LEFT_REGEX_B64` | base64-encoded regex matching a "player left" log line |

Each regex is a **Perl** pattern with optional named groups `(?<id>…)` and/or `(?<name>…)`. **Unset or empty → that detection is disabled** — the shim stays out of the way and emits nothing. Presence is never faked: no pattern means no events, not a fabricated count.

### Output line schema (`/run/kgsm/events.ndjson`)

```json
{"type":"player_joined","id":"<id|null>","name":"<name|null>","ts":"<ISO-8601-UTC>"}
{"type":"player_left","id":"<id|null>","name":"<name|null>","ts":"<ISO-8601-UTC>"}
```

A match that captures neither an id nor a name is skipped (never emitted as `{null,null}`). The file is created fresh on each container start.

The shim is strictly additive — it never reroutes the game's stdout and never touches the management script or its stop/save path.

## ➕ Adding a New Game Image

Create `images/<game>/` with a `Dockerfile`, a `build.sh` (copy an existing game's), and your management/launch script. The Dockerfile follows this pattern:

```dockerfile
# Pin the shared base — never bare `FROM kgsm-base`.
FROM kgsm-base:1.0

EXPOSE 7777/udp 27015/udp

ARG DEBIAN_FRONTEND=noninteractive
ENV SERVER_HOME=/opt/<game> \
    MANAGEMENT_FILE=/opt/<game>/<game>.manage.sh

# Game server directories (the kgsm user comes from the base).
RUN mkdir -p ${SERVER_HOME}/{backups,install,logs,saves,temp} \
  && chown -R ${USER}:${USER} ${SERVER_HOME}

# Only game-specific dependencies here — the common toolchain is in kgsm-base.
RUN apt-get update && apt-get install -y --no-install-recommends <pkgs> \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --chown=${USER}:${USER} --chmod=0755 ./<game>.manage.sh ${MANAGEMENT_FILE}

WORKDIR ${SERVER_HOME}
USER ${USER}

# Set CMD, NOT ENTRYPOINT — the base ENTRYPOINT (tini → wrapper → shim) runs this verbatim.
CMD ["/opt/<game>/<game>.manage.sh", "--start"]
```

Key rules: pin the base version, add **only** game-specific deps, and set **`CMD`** (not `ENTRYPOINT`). To enable presence detection, supply the two regex env vars (KGSM does this from the blueprint).

## 🤝 Contributing

We welcome new game server images! See [CONTRIBUTING.md](CONTRIBUTING.md). Follow the [Adding a New Game Image](#-adding-a-new-game-image) pattern above, or start from the skeleton in `templates/`.

## 📄 License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
