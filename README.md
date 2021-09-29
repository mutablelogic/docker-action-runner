# docker-action-runner

This repository contains code to create a docker image for a github action runner,
and instructions for using it. The most useful guide I found was [here](https://testdriven.io/blog/github-actions-docker/) and this repository is based on that.

I am targetting ARM 32-bit (armhf) here as the environment for the runner.

## Setup

In order to create the image the first time, you'll need to install docker, as per
[this guide](https://docs.docker.com/engine/install/ubuntu/). Then download the repository
and build the image, assuming you are on ARM:

```bash
[bash] git clone git@github.com:mutablelogic/docker-action-runner.git
[bash] cd docker-action-runner
[bash] docker build --tag runner-image-arm .
[bash] docker image ls runner-image-arm
```

Re-tag the image for uploading to docker (or whatever other registry service you're using)
and push to that registry:

```bash
[bash] ORGANIZATION="mutablelogic"
[bash] REGISTRY="ghcr.io/${ORGANIZATION}"
[bash] VERSION=`git tag`
[bash] docker login "${REGISTRY}"
[bash] docker tag runner-image-arm "${REGISTRY}/runner-image-arm:${VERSION#v}"
[bash] docker push "${REGISTRY}/runner-image-arm:${VERSION#v}"
[bash] docker tag runner-image-arm "${REGISTRY}/runner-image-arm:latest"
[bash] docker push "${REGISTRY}/runner-image-arm:latest"
[bash] docker image rm runner-image-arm:latest
```
