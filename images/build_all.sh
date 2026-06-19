#!/usr/bin/env bash

echo "Building all images..."

push=
if [[ "$1" == "--push" ]]; then
  push="--push"
fi

# The shared base image must be built first — every game image derives
# `FROM kgsm-base`, so a missing base fails the rest of the builds.
if [[ -f "base/build.sh" ]]; then
  cd "base" || exit 1
  ./build.sh $push
  cd ..
fi

for dir in */; do
  # Already built above.
  [[ "$dir" == "base/" ]] && continue
  if [[ -f "${dir}/build.sh" ]]; then
    cd "$dir" || continue
    ./build.sh $push
    cd ..
  fi
done

echo "Removing dangling images..."

docker image prune
