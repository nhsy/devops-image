# DevOps Image
[![Build and Push](https://github.com/nhsy/devops-image/actions/workflows/main.yml/badge.svg)](https://github.com/nhsy/gcp-devops-image/actions/workflows/main.yml)

## Introduction
The aim of this container image is to provide a baseline devops environment for usage across multiple projects.

Configuration files for gcloud, ssh and terraform are kept separate from the host OS home folder.

The Dockerfile pre-installs the following tools:

* ansible
* gcloud sdk
* kubectl
* mkdocs
* packer
* python3
* terraform
* terragrunt
* tflint
* tfswith
* tfsec
* zsh

## Pre-Requisites

A suitable docker environment is needed to build and run the image:
* Docker CE for Linux
* Docker Desktop for macOS or Windows
* Windows + WSL2 + Ubuntu VM + Docker CE 

N.B. For M1 Macbooks please use the latest version of Docker Desktop v4.7.1 or later.

## Customising the image
Amend the version ARGS to your requirements in the Dockerfile:

```text
ARG GCLOUD_VERSION=383.0.1
ARG PACKER_VERSION=1.8.0
ARG TERRAGRUNT_VERSION=0.36.6
ARG TFLINT_VERSION=0.35.0
ARG TFSEC_VERSION=1.17.0
```

## Building the image
docker build --pull --force-rm --no-cache --tag gcp-devops .

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
Navigate to your project folder end execute:
```shell
~/docker-start.sh
```

## Troubleshooting
The Dockerfile uses the auto populated ARG `TARGETARCH`.

If errors are encountered during `docker build` please check this value is being set to either `amd64` or `arm64` in the build output.

https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope

https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/

## Multi CPU Architecture Builds
The docker image can be built and tested for multiple platforms.

Setup your docker environment using the instructions in the link below:

https://docs.docker.com/desktop/multi-arch/

Run the following command to create an image for the platforms linux/arm64 and linux/amd64.
```shell
docker buildx build --pull --force-rm --no-cache --tag gcp-devops --platform linux/arm64,linux/amd64 .
```
