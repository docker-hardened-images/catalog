## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you may need to authenticate to the registry to pull the images.

## What's included in this ECK Operator image

This Docker Hardened ECK Operator image includes:

- elastic-operator (binary; default command: `manager`)
- Default operator config at `/conf/eck.yaml`
- License and notice files under `/licenses/`

## Start an ECK Operator image

Replace `<tag>` with the image variant you want to run (e.g. `3`, `3.3.1`, `3-fips`, `3-dev`).

Use the `--help` flag to see usage and options:

```bash
$ docker run --rm dhi/eck-operator:<tag> --help
```

For deployment on Kubernetes, use the
[official ECK installation guide](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html) and set the
operator image to your DHI image (e.g. `dhi/eck-operator:<tag>`).

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate to a Docker Hardened ECK Operator image, follow these steps:

1. **Find hardened images for your app.**\
   Inspect the image tags and choose the variant that matches your ECK major version (e.g. `2` or `3`) and patch level
   (e.g. `2.16.1`, `3.3.1`).

1. **Update the operator image reference.**\
   In your Helm values, Kubernetes manifests, or deployment configuration, replace the existing ECK operator image with
   the DHI image (e.g. `dhi/eck-operator:3` or `dhi/eck-operator:2`). All existing command-line arguments, environment
   variables, and settings remain the same.

1. **For multi-stage or custom Dockerfiles**, use the DHI image as the runtime base. Use non-dev DHI images for the
   final stage that runs the operator.

1. **Install additional packages only if needed.**\
   The runtime image does not include a package manager. If you need extra tools, use a multi-stage build with a `dev`
   image in the build stage and copy artifacts into the runtime stage, or use Docker Debug for ad-hoc debugging.

## Troubleshooting migration

### General debugging

Runtime images do not include a shell. Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach
a shell and debugging tools to a running container.

### Permissions

The image runs as a nonroot user by default. Ensure any mounted config or data paths are readable (and writable when
required) by the container user.

### Entry point

The DHI image uses entrypoint `/usr/local/bin/elastic-operator` (normalized path) while the upstream image uses
`/elastic-operator`. Both execute the same binary with default command `manager`. This path difference is transparent to
Kubernetes deployments but may need adjustment if you override the entrypoint in custom configurations.
