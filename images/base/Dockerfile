# KGSM base image
# Shared foundation for all KGSM game-server images: the non-root kgsm user,
# the common SteamCMD/wine/xvfb toolchain, tini as PID 1, and the additive
# player-presence detection shim. Per-game images derive `FROM kgsm-base` and
# add only their game-specific dependencies + launch command.
#
# Author: Cristian Moraru <cristian.moraru@live.com>
# Version: 1.0
#
# Copyright (c) 2025 The Krystal Ship
# Licensed under the GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html

# Starter image based on SteamCMD
FROM steamcmd/steamcmd:debian

LABEL org.opencontainers.image.source=https://github.com/TheKrystalShip/KGSM-Containers
LABEL org.opencontainers.image.authors="cristian.moraru@live.com"

# Build vars (non-persistent)
ARG DEBIAN_FRONTEND=noninteractive

# Environment variables (persistent)
ENV USER=kgsm \
  HOME=/home/kgsm \
  KGSM_EVENTS_DIR=/run/kgsm \
  KGSM_GAME_LOG=/run/kgsm/game.log

# Create the non-root user, the X11 socket dir, and the in-container event
# channel dir (/run/kgsm) owned by kgsm so the unprivileged shim can write it.
RUN useradd -m -d ${HOME} ${USER} \
  && mkdir -p /tmp/.X11-unix \
  && chown -R root:root /tmp/.X11-unix \
  && chmod 1777 /tmp/.X11-unix \
  && mkdir -p ${KGSM_EVENTS_DIR} \
  && chown -R ${USER}:${USER} ${KGSM_EVENTS_DIR}

# Install the common toolchain + tini (PID-1 init) and clean up. Game-specific
# packages stay in the per-game Dockerfiles.
RUN dpkg --add-architecture i386 \
  && apt-get update \
  && apt-get install \
  -y \
  --no-install-recommends \
  --no-install-suggests \
  tini \
  locales \
  xvfb \
  wine64 \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen \
  && apt-get clean autoclean \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/*

# Ship the base entrypoint + presence shim under /opt/kgsm.
COPY --chown=${USER}:${USER} --chmod=0755 ./entrypoint-base.sh /opt/kgsm/entrypoint-base.sh
COPY --chown=${USER}:${USER} --chmod=0755 ./kgsm-presence-shim.sh /opt/kgsm/kgsm-presence-shim.sh

# tini is PID 1 and forwards signals; it exec's the base entrypoint, which
# starts the shim and then exec's the per-game CMD. Derived images set CMD to
# their exact launch command (the verbatim command that used to be ENTRYPOINT).
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/kgsm/entrypoint-base.sh"]
