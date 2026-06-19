#!/usr/bin/env bash

# Builds the shared kgsm-base image. Per-game images derive `FROM kgsm-base`,
# so this must be built (and, when publishing, pushed) before them.

local_image="kgsm-base"
# GitHub Container Registry path
ghcr_image="ghcr.io/thekrystalship/${local_image}"
# Docker Hub path
dockerhub_image="thekrystalship/${local_image}"

echo "Building ${local_image}..."
docker build -t "${local_image}" .

echo "Tagging ${local_image} for GitHub Container Registry..."
docker image tag "${local_image}" "${ghcr_image}"

echo "Tagging ${local_image} for Docker Hub..."
docker image tag "${local_image}" "${dockerhub_image}"

if [[ "$1" == "--push" ]]; then
  echo "Pushing ${ghcr_image} to GitHub Container Registry..."
  docker push "${ghcr_image}"

  echo "Pushing ${dockerhub_image} to Docker Hub..."
  docker push "${dockerhub_image}"
fi
