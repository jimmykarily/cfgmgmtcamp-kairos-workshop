# Stage 2: Build your own immutable OS

Docs:
  - [The Kairos Factory](https://kairos.io/docs/reference/kairos-factory/)

## Prepare your base image

Add some packages to the Dockerfile below and then build the image:

```Dockerfile
ARG BASE_IMAGE=ubuntu:22.04

FROM quay.io/kairos/kairos-init:v0.6.2 AS kairos-init

FROM ${BASE_IMAGE} AS base-kairos

# Add your packages here. There are some examples.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl vim htop && \
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

## Create an ISO using AuroraBoot

```bash
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $PWD/build:/result \
  quay.io/kairos/auroraboot:latest \
  build-iso --output /result kairos-custom:latest
```

## Run it

Use the instructions in [stage-1](stage-1.md) to create a VM and run the ISO
you just created.

✅ Done! 🎉
