# KGSM Dockerfile for The Forest Dedicated Server
# This file is based on jonakoudijs/docker-forest (https://github.com/jonakoudijs/docker-forest)
# with modifications done to allow integration with KGSM.
#
# Author: Cristian Moraru <cristian.moraru@live.com>
# Version: 1.0
#
# Copyright (c) 2025 The Krystal Ship
# Licensed under the GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html

# Shared KGSM base (kgsm user, common toolchain, tini PID 1, presence shim)
FROM kgsm-base

LABEL org.opencontainers.image.source=https://github.com/TheKrystalShip/KGSM-Containers
LABEL org.opencontainers.image.authors="cristian.moraru@live.com"

# Port mapping
EXPOSE 8766/udp 8766/tcp 27015/udp 27015/tcp 27016/udp 27016/tcp

# Build vars (non-persistent)
ARG DEBIAN_FRONTEND=noninteractive

# Environment variables (persistent)
ENV SERVER_HOME=/opt/theforest \
  MANAGEMENT_FILE=/opt/theforest/theforest.manage.sh

# Create the game directories owned by the kgsm user (the user itself comes
# from kgsm-base).
RUN mkdir -p ${SERVER_HOME}/{backups,install,logs,saves,temp} \
  && chown -R ${USER}:${USER} ${SERVER_HOME}

# Copy entrypoint with ownership and permissions
COPY --chown=${USER}:${USER} --chmod=0755 ./theforest.manage.sh /opt/theforest/theforest.manage.sh

# Set working directory and switch to non-root user
WORKDIR ${SERVER_HOME}
USER ${USER}

# The base ENTRYPOINT (tini -> base entrypoint -> shim + launch) runs this CMD
# verbatim — the exact command that was previously ENTRYPOINT + CMD.
CMD ["/opt/theforest/theforest.manage.sh", "--start"]
