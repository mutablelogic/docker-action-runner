# docker-action-runner

This repository contains code to create a docker image for a github action runner,
and instructions for using it. The most useful guide I found was 
[here](https://testdriven.io/blog/github-actions-docker/) and this repository is based on that.

I am targetting ARM 32-bit (armhf) and 64-bit (arm64), my use case is
to be able to run GitHub Actions on ARM (which are not supported by default). 
The environment that is built into docker images is:

  * Architecture armhf (32-bit) and arm64
  * Ubuntu 18.04 (Bionic) or 20.04 (Focal). Bionic is currently preferred.
  * Github Action Runner 2.303
  * Additional packages `git`, `gh`, `docker-compose`, `pkg-config`,
      `protobuf-compiler`, `libprotobuf-dev`, `libmosquitto-dev`,
      `libavcodec-dev`, `libavdevice-dev`, `libavfilter-dev`, `libavformat-dev`,
      `libavresample-dev`, `libavutil-dev` and `libchromaprint-dev`

## Setup

In order to create the image the first time, you'll need to install docker, as per
[this guide](https://docs.docker.com/engine/install/ubuntu/). Then download the repository
and build the image, assuming you are on `arm64`. The ARCH value of `arm` is also possible
if you are on ARM 32-bit:

```bash
[bash] git clone git@github.com:mutablelogic/docker-action-runner.git
[bash] cd docker-action-runner && RUNNER_ARCH="arm64"
[bash] docker build \
  --tag "runner-image-${RUNNER_ARCH}" \
  --build-arg RUNNER_VERSION="2.283.3" \
  --build-arg RUNNER_ARCH="${RUNNER_ARCH}" \
  -f Dockerfile-bionic .
```

Re-tag the image for uploading to docker (or whatever other registry service you're using)
and push to that registry once you know it's worked:

```bash
[bash] RUNNER_ARCH="arm64" ORGANIZATION="mutablelogic" REGISTRY="ghcr.io/${ORGANIZATION}" \
       IMAGE="runner-image-${RUNNER_ARCH}" VERSION=`git describe --tags` 
[bash] echo "Push: ${REGISTRY}/${IMAGE}:${VERSION#v}"
[bash] docker login "${REGISTRY}"
[bash] docker tag "${IMAGE}" "${REGISTRY}/${IMAGE}:${VERSION#v}" && docker tag "${IMAGE}" "${REGISTRY}/${IMAGE}:latest"
[bash] docker push "${REGISTRY}/${IMAGE}:${VERSION#v}" && docker push "${REGISTRY}/${IMAGE}" && docker image rm "${IMAGE}"
```

At this point you would have your images in the registry ready for use. I also made the following changes on my Raspberry Pi:

  * I added `cgroup_enable=memory` to the file `/boot/cmdline.txt` and rebooted, so that nomad (see below) can use the memory cgroups support. You need to reboot the 
  Raspberry Pi to make the changes take effect;
  * I downloaded and installed `libseccomp2_2.5.1-1_armhf.deb` from [here](http://ftp.us.debian.org/debian/pool/main/libs/libseccomp/libseccomp2_2.5.1-1_armhf.deb) which fixed an issue with building the container on ARM (change `armhf` to `arm64` as necessary).

## Creating a manifest

If you have a number of images with different architectures you want to combine into a
single manifest, please see the __GitHub Actions__ workflow below.

## Running the runner

You then have a choice of running directly with docker or using an orchestration tool like [Nomad](https://www.nomadproject.io/).
The environment variables you need to set in order to manage the runner environment are:

  * `ORGANIZATION`: Where you're storing the runner image in the registry and the organization attached to the runner;
  * `ACCESS_TOKEN`: Create a personal access token in GitHub [here](https://github.com/settings/tokens). The token should have `admin:org` permissions.
  * `NAME`: The name of the runner, which is used to identify it on GitHub (optional);
  * `LABELS`: Comma-separated labels for the runner (optional). These are in addition
    to the existing labels `self-hosted, linux, arm` or similar;
  * `GROUP`: The runner group. Set to 'Default' if not otherwise set.

### Docker

If you're using Docker to create a runner action process, create a personal access token in GitHub [here](https://github.com/settings/tokens).
The token should have `admin:org` permissions. The token should be set as an environment variable `ACCESS_TOKEN`.

```bash
[bash] ORGANIZATION="mutablelogic" REGISTRY="ghcr.io/${ORGANIZATION}" ACCESS_TOKEN="XXXXXXX"
[bash] docker run --detach --name action-runner \
  --env ORGANIZATION="${ORGANIZATION}" --env ACCESS_TOKEN="${ACCESS_TOKEN}" \
  --env NAME="${HOSTNAME}" --env LABELS="" --env GROUP="" \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  "${REGISTRY}/runner-image:latest"
[bash] docker logs -f action-runner
```

(If you have a previously running container, you can remove it first with `docker stop action-runner && docker rm action-runner`).

When you see the line "Listening for Jobs" you can then scoot over to the GitHub Actions page to see that the runner is working. 
The page will be `https://github.com/organizations/${ORGANIZATION}/settings/actions/runners`

### Nomad

Here is a typical nomad job file that will run the runner:

```hcl
variable "access_token" {
  type = string
}

variable "github_username" {
  type = string
  default = "djthorpe"
}

variable "organization" {
  type = string
  default = "mutablelogic"
}

variable "datacenters" {
  type = list(string)
  default = [ "10707" ]
}

variable "image" {
  type = string
  default = "ghcr.io/mutablelogic/runner-image"
}

job "action-runner" {
  type         = "system"
  datacenters  = var.datacenters

  task "runner" {
    driver = "docker"

    env {
      ORGANIZATION = var.organization
      NAME         = node.unique.name
      LABELS       = node.datacenter
      ACCESS_TOKEN = var.access_token
    }

    config {
      image       = var.image
      auth {
        username  = var.github_username
        password  = var.access_token
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

You'll need to have `var.access_token`, defined elsewhere, for example you can invoke from the command line:

```bash
[bash] nomad job run \
  -var -var access_token=${ACCESS_TOKEN} \
  action-runner.hcl 
```

Your configuration for Nomad may also need to be updated for docker:

```hcl
plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}
```

## GitHub Actions to build the image

Finally, you can then create a GitHub action which will build the images and a
manifest, which is part of this repository [here](https://github.com/mutablelogic/docker-action-runner/blob/main/.github/workflows/make-image.yaml). These images
are currently private but you can set up your own workflow or let me know and I can
make the images visible to you.

## References

Here are some references I found useful:

  * https://testdriven.io/blog/github-actions-docker/
  * https://docs.docker.com/engine/install/ubuntu/
  * https://github.com/myoung34/docker-github-actions-runner
  * https://github.com/actions/runner/releases


