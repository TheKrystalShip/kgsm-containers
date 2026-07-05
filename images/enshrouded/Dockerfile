# KGSM Dockerfile for Enshrouded Dedicated Server
# This file is based on sknnr/enshrouded-dedicated-server (https://github.com/jsknnr/enshrouded-server)
# with modifications done to allow integration with KGSM.
#
# Author: Cristian Moraru <cristian.moraru@live.com>
# Version: 1.0
#
# Copyright (c) 2025 The Krystal Ship
# Licensed under the GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html

# Shared KGSM base (kgsm user, common toolchain, tini PID 1, presence shim).
# Pinned to a base version so a future kgsm-base rebuild can't silently change us.
FROM kgsm-base:1.0

LABEL org.opencontainers.image.source=https://github.com/TheKrystalShip/KGSM-Containers
LABEL org.opencontainers.image.authors="cristian.moraru@live.com"

# Port mapping
EXPOSE 15636/udp 15637/udp 27015/udp 27016/udp

# Build vars (non-persistent)
ARG DEBIAN_FRONTEND=noninteractive

# Environment variables (persistent)
ENV SERVER_HOME=/opt/enshrouded \
  MANAGEMENT_FILE=/opt/enshrouded/enshrouded.manage.sh

# Create the game directories owned by the kgsm user (the user itself comes
# from kgsm-base).
RUN mkdir -p ${SERVER_HOME}/{backups,install,logs,saves,temp} \
  && chown -R ${USER}:${USER} ${SERVER_HOME}

# Install game-specific dependencies and clean up (common toolchain is in
# kgsm-base). Enshrouded needs the 32-bit wine stack + winetricks runtime, and
# inotify-tools for the manage script's `--logs --follow`.
RUN apt-get update \
  && apt-get install \
  -y \
  --no-install-recommends \
  --no-install-suggests \
  lib32gcc-s1 \
  cabextract \
  wine32:i386 \
  winbind \
  winetricks \
  inotify-tools \
  && apt-get clean autoclean \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/*

# Copy the management script (same contract as every other KGSM game image).
COPY --chown=${USER}:${USER} --chmod=0755 ./enshrouded.manage.sh /opt/enshrouded/enshrouded.manage.sh

# Set working directory and switch to non-root user
WORKDIR ${SERVER_HOME}
USER ${USER}

# Bake the wine prefix at IMAGE-BUILD time instead of on every container start
# (the old entrypoint.sh re-ran all of this on each boot). Initialise the
# prefix, install the runtime bits Enshrouded needs (corefonts + vcrun2022 for
# .NET), and pin the Windows version — all under a throwaway Xvfb. The prefix
# lives in the kgsm user's HOME (baked into the image layer), so `_start` only
# has to launch wine. Kept non-fatal to mirror the original behaviour; runtime
# validation catches a bad prefix.
RUN Xvfb :1 -screen 0 800x600x24 >/dev/null 2>&1 & \
  export DISPLAY=:1 WINEDLLOVERRIDES="mscoree=d" WINEDEBUG=-all; \
  sleep 3; \
  wineboot --init /nogui; \
  winetricks -q corefonts sound=disabled vcrun2022; \
  wine winecfg -v win10; \
  wineserver -w; \
  rm -rf ${HOME}/.cache

# The base ENTRYPOINT (tini -> base entrypoint -> shim + launch) runs this CMD
# verbatim. Enshrouded now uses the same management script as every other KGSM
# game image (the standard start/stop/save/update/backup contract), replacing
# the legacy bespoke entrypoint.sh.
CMD ["/opt/enshrouded/enshrouded.manage.sh", "--start"]
