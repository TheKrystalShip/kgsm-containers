#!/usr/bin/env bash

# Builds the shared kgsm-base image. Per-game images PIN `FROM kgsm-base:${version}`
# (see each game Dockerfile) so a base change does NOT silently affect games — bump
# `version` here AND the `FROM kgsm-base:<v>` line in every game Dockerfile together,
# deliberately. This must run before the game builds (they derive from it).

local_image="kgsm-base"
# Base image version — the single source of truth. Game Dockerfiles pin
# `FROM kgsm-base:${version}`; bump both in lockstep when the base changes in a
# way games should adopt.
version="1.0"
# GitHub Container Registry path
ghcr_image="ghcr.io/thekrystalship/${local_image}"
# Docker Hub path
dockerhub_image="thekrystalship/${local_image}"

echo "Building ${local_image}:${version}..."
# Tag both the pinned version (what games derive from) and :latest (floating).
docker build -t "${local_image}:${version}" -t "${local_image}:latest" .

echo "Tagging ${local_image} for GitHub Container Registry..."
docker image tag "${local_image}:${version}" "${ghcr_image}:${version}"
docker image tag "${local_image}:${version}" "${ghcr_image}:latest"

echo "Tagging ${local_image} for Docker Hub..."
docker image tag "${local_image}:${version}" "${dockerhub_image}:${version}"
docker image tag "${local_image}:${version}" "${dockerhub_image}:latest"

if [[ "$1" == "--push" ]]; then
  echo "Pushing ${ghcr_image} (${version} + latest) to GitHub Container Registry..."
  docker push "${ghcr_image}:${version}"
  docker push "${ghcr_image}:latest"

  echo "Pushing ${dockerhub_image} (${version} + latest) to Docker Hub..."
  docker push "${dockerhub_image}:${version}"
  docker push "${dockerhub_image}:latest"
fi
