# KGSM Dockerfile for <game-name>
# This file is based on <name> (<link>)
# with modifications done to allow integration with KGSM.
#
# Author: <your-name> <your-email>
# Version: 1.0
#
# Copyright (c) 2025 The Krystal Ship
# Licensed under the GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html

# This file is an example. Replace the <placeholders> with real values and
# adjust as necessary. Build the shared base first: (cd ../base && ./build.sh)

# Shared KGSM base (kgsm user, common toolchain, tini PID 1, presence shim).
# Pinned to a base version so a future kgsm-base rebuild can't silently change us.
FROM kgsm-base:1.0

LABEL org.opencontainers.image.source=https://github.com/TheKrystalShip/KGSM-Containers
LABEL org.opencontainers.image.authors="<your-email>"

# Port mapping
EXPOSE 7777/udp 27015/udp

# Build vars (non-persistent)
ARG DEBIAN_FRONTEND=noninteractive

# Environment variables (persistent). The kgsm user, HOME, and the common
# toolchain all come from kgsm-base — set only what is game-specific here.
ENV SERVER_HOME=/opt/<game-name> \
  MANAGEMENT_FILE=/opt/<game-name>/<game-name>.manage.sh

# Create the game directories (the kgsm user itself comes from kgsm-base).
RUN mkdir -p ${SERVER_HOME}/{backups,install,logs,saves,temp} \
  && chown -R ${USER}:${USER} ${SERVER_HOME}

# Install ONLY game-specific dependencies — the common toolchain (wine64, xvfb,
# locales, steamcmd) is already in kgsm-base. Drop this whole RUN if the game
# needs nothing extra.
RUN apt-get update \
  && apt-get install \
  -y \
  --no-install-recommends \
  --no-install-suggests \
  <game-specific-packages> \
  && apt-get clean autoclean \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/*

# Copy the management/launch script with ownership and permissions
COPY --chown=${USER}:${USER} --chmod=0755 ./<game-name>.manage.sh /opt/<game-name>/<game-name>.manage.sh

# Set working directory and switch to the non-root kgsm user
WORKDIR ${SERVER_HOME}
USER ${USER}

# Set CMD, NOT ENTRYPOINT. The base ENTRYPOINT (tini -> entrypoint-base.sh ->
# presence shim + launch) runs this CMD verbatim — it is the exact command that
# used to be ENTRYPOINT + CMD.
CMD ["/opt/<game-name>/<game-name>.manage.sh", "--start"]
