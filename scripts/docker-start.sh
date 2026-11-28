#!/bin/bash
set -euo pipefail

NAME="$(basename "$PWD")"-$RANDOM

[ ! -d "$(pwd)/.config" ] && mkdir "$(pwd)/.config"
[ ! -d "$(pwd)/.ssh" ] && mkdir "$(pwd)/.ssh"
[ ! -f "$(pwd)/.terraformrc" ] && touch "$(pwd)/.terraformrc"

echo "Starting container - $NAME"
docker run -ti --rm \
    -v "$(pwd)"/.config:/home/devops/.config \
    -v "$(pwd)"/.ssh:/home/devops/.ssh \
    -v "$(pwd)"/.terraformrc:/home/devops/.terraformrc \
    -v "$(pwd)":/work \
    -w /work \
    --name "$NAME" \
    gcp-devops
