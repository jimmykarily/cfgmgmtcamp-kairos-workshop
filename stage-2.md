# Stage 2: Build your own immutable OS

Docs:
  - [The Kairos Factory](https://kairos.io/docs/reference/kairos-factory/)

## Prepare your base image

> [!NOTE]
> This step has to be run locally or in your pipeline, not in the Kairos VM.

Add some packages to the Dockerfile below and then build the image (better keep
`git` in the package list. That will prove useful in [stage-6](stage-6.md)).

```Dockerfile
ARG BASE_IMAGE=ubuntu:22.04

FROM quay.io/kairos/kairos-init:v0.6.2 AS kairos-init

FROM ${BASE_IMAGE} AS base-kairos

# Add your packages here. These are some examples:
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl vim htop git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# "Kairosify" the image
RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init --stage install \
      --level debug \
      --model "generic" \
      --trusted "false" \
      --provider k3s \
      --provider-k3s-version "v1.35.0+k3s1" \
      --version "v0.0.1" \
    && \
    /kairos-init --stage init \
      --level debug \
      --model "generic" \
      --trusted "false" \
      --provider k3s \
      --provider-k3s-version "v1.35.0+k3s1" \
      --version "v0.0.1"
```

```bash
docker build --progress plain -t kairos-custom:latest .
```

## Alternative: Using Hadron (smaller image)

If you prefer a smaller base image, you can use [Hadron](https://github.com/kairos-io/hadron)
instead of Ubuntu. Hadron is a minimal base image without a package manager, which results
in significantly smaller images.

Note: Since Hadron has no package manager, you cannot install additional packages like `git`.
This means for [stage-6](stage-6.md), you'll need to use the alternative method to deploy
the kairos-operator (see the Hadron-specific instructions there).

```Dockerfile
ARG BASE_IMAGE=ghcr.io/kairos-io/hadron:v0.0.1

FROM quay.io/kairos/kairos-init:v0.7.0 AS kairos-init

FROM ${BASE_IMAGE} AS base-kairos

# Example: create a custom file
RUN touch /etc/myfile-exists

# "Kairosify" the image
RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init --stage install \
      --level debug \
      --model "generic" \
      --trusted "false" \
      --provider k3s \
      --provider-k3s-version "v1.35.0+k3s1" \
      --version "v0.0.1" \
    && \
    /kairos-init --stage init \
      --level debug \
      --model "generic" \
      --trusted "false" \
      --provider k3s \
      --provider-k3s-version "v1.35.0+k3s1" \
      --version "v0.0.1"
```

```bash
docker build --progress plain -t kairos-custom:latest .
```

## Create an ISO using AuroraBoot

```bash
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $PWD/build:/result \
  quay.io/kairos/auroraboot:latest \
  build-iso --output /result kairos-custom:latest
```

If the build is successful, you should find the ISO file in the `$PWD/build` directory.

## Run it

Use the instructions in [stage-1](stage-1.md) to create a VM and run the ISO
you just created.

You should be able to find your modifications when you boot the image.

✅ Done! 🎉
