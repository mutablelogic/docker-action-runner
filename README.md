# docker-action-runner

This repository contains code to create a docker image for a github action runner,
and instructions for using it. The most useful guide I found was 
[here](https://testdriven.io/blog/github-actions-docker/) and this repository is based on that.

I am targetting ARM 32-bit (armhf) and 64-bit (arm64), my use case is
to be able to run GitHub Actions on ARM (which are not supported by default). 
The environment that is built into docker images is:

  * Architecture armhf (32-bit) and arm64
  * Ubuntu 20.04
  * Github Action Runner 2.283.3
  * Additional packages `git`, `gh`, `docker-compose`, `pkg-config` and `libmosquitto-dev`

## Setup

In order to create the image the first time, you'll need to install docker, as per
[this guide](https://docs.docker.com/engine/install/ubuntu/). Then download the repository
and build the image, assuming you are on `arm64`. The ARCH value of `arm` is also possible
if you are on ARM 32-bit:

```bash
[bash] git clone git@github.com:mutablelogic/docker-action-runner.git
[bash] cd docker-action-runner
[bash] ARCH=arm64; docker build --tag runner-image-${ARCH} --build-arg RUNNER_VERSION="2.283.3" --build-arg RUNNER_ARCH="${ARCH}" .
```

Re-tag the image for uploading to docker (or whatever other registry service you're using)
and push to that registry once you know it's worked:

```bash
[bash] ARCH="arm64" ORGANIZATION="mutablelogic" REGISTRY="ghcr.io/${ORGANIZATION}" IMAGE="runner-image-${ARCH}" VERSION=`git describe --tags` 
[bash] echo "Push: ${REGISTRY}/${IMAGE}:${VERSION#v}"
[bash] docker login "${REGISTRY}"
[bash] docker tag "${IMAGE}" "${REGISTRY}/${IMAGE}:${VERSION#v}" && docker tag "${IMAGE}" "${REGISTRY}/${IMAGE}:latest"
[bash] docker push "${REGISTRY}/${IMAGE}:${VERSION#v}" && docker push "${REGISTRY}/${IMAGE}" && docker image rm "${IMAGE}"
```

At this point you would have your images in the registry ready for use. I also made the following changes:

  * I added `cgroup_enable=memory` to the file `/boot/cmdline.txt` and rebooted, so that nomad (see below)
    can use the memory cgroups support. You need to reboot the Raspberry Pi to make the changes take effect;
  * I downloaded and installed `libseccomp2_2.5.1-1_armhf.deb` from [here](http://ftp.us.debian.org/debian/pool/main/libs/libseccomp/libseccomp2_2.5.1-1_armhf.deb) which fixed an issue with building the container on ARM.

## Creating a manifest

If you have a number of images with different architectures you want to combine, use `docker manifest`. For example,

```bash
[bash] ORGANIZATION="mutablelogic" REGISTRY="ghcr.io/${ORGANIZATION}" MANIFEST="runner-image" VERSION=`git describe --tags`
[bash] docker pull "${REGISTRY}/${MANIFEST}-arm:${VERSION#v}" && docker pull "${REGISTRY}/${MANIFEST}-arm64:${VERSION#v}"
[bash] docker manifest create "${REGISTRY}/${MANIFEST}:${VERSION#v}" \
  --amend "${REGISTRY}/${MANIFEST}-arm:${VERSION#v}" \
  --amend "${REGISTRY}/${MANIFEST}-arm64:${VERSION#v}"
[bash] echo "Push: ${REGISTRY}/${MANIFEST}:${VERSION#v}"
[bash] docker push "${REGISTRY}/${MANIFEST}:${VERSION#v}"
```

## Running the runner

You then have a choice of running directly with docker or using an orchestration tool like [Nomad](https://www.nomadproject.io/).
The environment variables you need to set in order to manage the runner environment are:

  * `ORGANIZATION`: Where you're storing the runner image in the registry and the organization attached to the runner;
  * `ACCESS_TOKEN`: Create a personal access token in GitHub [here](https://github.com/settings/tokens). The token should have `admin:org` permissions.
  * `NAME`: The name of the runner, which is used to identify it on GitHub (optional);
  * `LABELS`: Comma-separated labels for the runner (optional). Generally `self-hosted, linux, arm` or similar;
  * `GROUP`: The runner group. Set to 'Default' if not otherwise set.

### Docker

If you're using Docker to create a runner action process, create a personal access token in GitHub [here](https://github.com/settings/tokens).
The token should have `admin:org` permissions. The token should be set as an environment variable `ACCESS_TOKEN`.

```bash
[bash] ARCH="arm64" ORGANIZATION="mutablelogic" REGISTRY="ghcr.io/${ORGANIZATION}" ACCESS_TOKEN="XXXXXXX"
[bash] docker run --detach --name action-runner \
  --env ORGANIZATION="${ORGANIZATION}" --env ACCESS_TOKEN="${ACCESS_TOKEN}" \
  --env NAME="" --env LABELS="" --env GROUP="" \
  "${REGISTRY}/runner-image-${ARCH}"
[bash] docker logs -f action-runner
```

(If you have a previously running container, you can remove it first with `docker stop action-runner && docker rm action-runner`).

When you see the line "Listening for Jobs" you can then scoot over to the GitHub Actions page to see that the runner is working. 
The page will be `https://github.com/organizations/${ORGANIZATION}/settings/actions/runners`

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
      NAME = "XXXXX"
      LABELS = "XXXXX'
      GROUP = "XXXXX"
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

## GitHub Actions to build the image

Finally, you can then create a GitHub action which will build the image, which is part
of this repository [here](https://github.com/mutablelogic/docker-action-runner/blob/main/.github/workflows/build-arm.yaml).

This will build the image and upload it to the registry.

## References

Here are some references I found useful:

  * https://testdriven.io/blog/github-actions-docker/
  * https://docs.docker.com/engine/install/ubuntu/
  * https://github.com/myoung34/docker-github-actions-runner
  * https://github.com/actions/runner/releases


