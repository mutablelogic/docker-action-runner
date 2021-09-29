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
[bash] VERSION=`git describe --tags`
[bash] docker login "${REGISTRY}"
[bash] docker tag runner-image-arm "${REGISTRY}/runner-image-arm:${VERSION#v}"
[bash] docker push "${REGISTRY}/runner-image-arm:${VERSION#v}"
[bash] docker tag runner-image-arm "${REGISTRY}/runner-image-arm:latest"
[bash] docker push "${REGISTRY}/runner-image-arm:latest"
[bash] docker image rm runner-image-arm:latest
```

At this point you would have your images in the registry ready for use.

## Running the runner

You then have a choice of running directly with docker or using an orchestration tool like [Nomad](https://www.nomadproject.io/):

### Docker

You then need to create a runner action process, which will run the image
and attach to GitHub Actions. Create a personal access token in GitHub [here](https://github.com/settings/tokens). The token should have `admin:org` permissions. The token should be set as an environment variable `ACCESS_TOKEN`.

```bash
[bash] ORGANIZATION="mutablelogic"
[bash] REGISTRY="ghcr.io/${ORGANIZATION}"
[bash] ACCESS_TOKEN="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
[bash] docker run --detach \
  --env ORGANIZATION="${ORGANIZATION}" --env ACCESS_TOKEN="${ACCESS_TOKEN}" \
  --name action-runner "${REGISTRY}/runner-image-arm:latest"
[bash] docker logs -f action-runner
```

(If you have a previously running container, you can remove it first with `docker stop action-runner && docker rm action-runner`).

When you see the line "Listening for Jobs" you can then scoot over to the GitHub Actions page to see that the runner is working. The page will be `https://github.com/organizations/${ORGANIZATION}/settings/actions/runners`

### Nomad

Here is a typical nomad job file that will run the runner:

```hcl
job "action-runner" {
  datacenters = [ "XXXXX" ]
  type        = "system"

  task "runner" {
    driver = "docker"

    env {
      ACCESS_TOKEN = "XXXXX"
      ORGANIZATION = "XXXXX"
    }

    config {
      image       = "ghcr.io/mutablelogic/runner-image-arm:latest"
      auth {
        username = "XXXXX"
        password = "XXXXX"
      }
      privileged  = true
      userns_mode = "host"
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock",
      ]
    }
  }
}
```

Of course, replace the `XXXXX` with your own values. Your client configuration for Nomad may also need to be updated:

```hcl
client {
  enabled = true
}

plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}
```
