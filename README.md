# DevOps Image

[![Build and Push](https://github.com/nhsy/devops-image/actions/workflows/main.yml/badge.svg)](https://github.com/nhsy/devops-image/actions/workflows/main.yml)

## Introduction

The aim of this container image is to provide a baseline devops environment for usage across multiple projects.

Configuration files for gcloud, ssh and terraform are kept separate from the host OS home folder.

The Dockerfile builds a shared `base` stage and two variants on top of it.

The `base` stage pre-installs:

* git, curl, jq, vim, tree, zip/unzip, gnupg, htop
* zsh + oh-my-zsh (the entrypoint shell for both variants)
* python3 + pip, Node.js 20
* pre-commit
* kubectl
* packer
* terraform
* terraform-docs
* terragrunt
* tflint
* go-task
* Claude Code, Codex, GitHub Copilot and Gemini CLIs

`gcp-devops` adds:

* gcloud SDK
* gke-gcloud-auth-plugin

`aws-devops` adds:

* AWS CLI v2
* Session Manager plugin
* boto3, cfn-lint

## Pre-Requisites

A suitable docker environment is needed to build and run the image:

* Docker CE for Linux
* Docker Desktop for macOS or Windows
* Windows + WSL2 + Ubuntu VM + Docker CE

N.B. For M1/M2/M3 Macbooks please use the latest version of Docker Desktop.

## CLI Tool Management

This project uses [Aqua](https://aquaproj.github.io/) to manage CLI tool versions (Terraform, Kubectl, Packer, etc.).

All tool versions are defined in [aqua.yaml](aqua.yaml).

To update a tool version, simply amend `aqua.yaml` and rebuild the image.

## Customising the image

Amend the version values in `aqua.yaml` for Aqua-managed tools.

For Python packages, update the `pip install` commands in the `Dockerfile`.

For System packages, update the `apt-get install` commands in the `Dockerfile`.

## Building the image

Using Taskfile (recommended):

```bash
task build:aws
# or
task build:gcp
# or build both
task build:all
```

Or using Docker directly:

```bash
docker build --pull --force-rm --no-cache --tag aws-devops --target aws-devops .
# or
docker build --pull --force-rm --no-cache --tag gcp-devops --target gcp-devops .
```

## Testing the image

```bash
task test:gcp
task test:aws
# or test both
task test:all
```

## Using the image

Create a shell script in your $HOME folder named `docker-start.sh` with the contents:

```shell
NAME="$(basename $PWD)"-$RANDOM

[ ! -d "$(pwd)/.config" ] && mkdir $(pwd)/.config
[ ! -d "$(pwd)/.ssh" ] && mkdir $(pwd)/.ssh
[ ! -f "$(pwd)/.terraformrc" ] && touch $(pwd)/.terraformrc

echo "Starting container - $NAME"
docker run -ti --rm \
    -v "$(pwd)"/.config:/root/.config \
    -v "$(pwd)"/.ssh:/root/.ssh \
    -v "$(pwd)"/.terraformrc:/root/.terraformrc \
    -v "$(pwd)":/work \
    -w /work \
    --name $NAME \
    gcp-devops
```

Navigate to your project folder and execute:

```shell
~/docker-start.sh
```

## Troubleshooting

The Dockerfile uses the auto populated ARG `TARGETARCH`.

If errors are encountered during `docker build` please check this value is being set to either `amd64` or `arm64` in the build output.

<https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope>

<https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/>
