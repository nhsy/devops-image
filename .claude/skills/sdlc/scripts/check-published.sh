#!/bin/bash
# Confirms a main commit was published: for each image, :<sha8> exists, is
# multi-arch (amd64 + arm64), and :latest points at the same index.
# Reads the registry only; pulls nothing.
# Usage: check-published.sh [commit]   (default: origin/main)
set -euo pipefail

commit="${1:-origin/main}"
sha8="$(git rev-parse --short=8 "$commit")"
owner="$(gh repo view --json owner --jq '.owner.login' | tr '[:upper:]' '[:lower:]')"
status=0

for image in gcp aws; do
  ref="ghcr.io/${owner}/${image}-devops-image"
  if ! tagged="$(docker buildx imagetools inspect "${ref}:${sha8}" --format '{{.Manifest.Digest}}' 2>/dev/null)"; then
    echo "FAIL ${image}: ${ref}:${sha8} not found"
    status=1
    continue
  fi
  latest="$(docker buildx imagetools inspect "${ref}:latest" --format '{{.Manifest.Digest}}')"
  platforms="$(docker buildx imagetools inspect "${ref}:${sha8}" --raw |
    jq -r '[.manifests[] | select(.platform.os == "linux") | .platform.architecture] | sort | join(",")')"
  if [ "$tagged" != "$latest" ]; then
    echo "FAIL ${image}: :latest (${latest}) is not :${sha8} (${tagged})"
    status=1
  elif [ "$platforms" != "amd64,arm64" ]; then
    echo "FAIL ${image}: platforms are '${platforms}', expected amd64,arm64"
    status=1
  else
    echo "ok   ${image}: :latest = :${sha8} = ${tagged} (${platforms})"
  fi
done

exit "$status"
