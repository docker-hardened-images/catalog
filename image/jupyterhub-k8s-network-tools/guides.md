## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image provides the iptables init container used by [Zero to JupyterHub on Kubernetes](https://z2jh.jupyter.org/)
(Z2JH). The chart invokes it with iptables commands as the container command.

### What's included in this JupyterHub K8s Network Tools image

This Docker Hardened Image ships `iptables` at `/usr/sbin/iptables`.

## Start JupyterHub K8s Network Tools

To confirm that the iptables binary is present and working, run it with `--version`. Replace `<version>` with the
desired version tag (for example, `4.4.0-alpine3.24`):

```console
docker run --rm \
  --entrypoint /usr/sbin/iptables \
  dhi.io/jupyterhub-k8s-network-tools:<version> \
  --version
```

### Use with Zero to JupyterHub on Kubernetes

The Z2JH Helm chart references this image as an init container on the hub pod. To override the image, set
`singleuser.networkTools.image.name` and `singleuser.networkTools.image.tag` in your chart values. Replace `<version>`
with the desired version tag:

```yaml
singleuser:
  networkTools:
    image:
      name: dhi.io/jupyterhub-k8s-network-tools
      tag: <version>
```

When deploying with the Zero to JupyterHub Helm chart, the chart sets the required security context automatically.

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Topic    | `quay.io/jupyterhub/k8s-network-tools` (upstream) | `dhi.io/jupyterhub-k8s-network-tools` (this image) |
| -------- | ------------------------------------------------- | -------------------------------------------------- |
| Base     | Alpine 3.18                                       | Alpine 3.24 or Debian 13 hardened runtime          |
| User     | root                                              | root (required for iptables)                       |
| Shell    | Present (Alpine default)                          | Runtime image has no shell; use Docker Debug       |
| iptables | `iptables` (nf_tables on Alpine 3.19+)            | `iptables` (nf_tables backend)                     |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as root (required for iptables)
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, override the image references in your Zero to JupyterHub Helm
chart values file.

| Item               | Migration note                                                                                                                                                |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace upstream image references with the Docker Hardened Image tag.                                                                                         |
| Package management | Runtime images don't contain package managers. Use dev-tagged images for debugging only.                                                                      |
| Privilege          | This image requires root and `CAP_NET_ADMIN`. No change from upstream — the chart sets the security context automatically.                                    |
| Entry point        | Docker Hardened Images may have different entry points than upstream images. Inspect entry points and update your deployment if necessary.                    |
| No shell           | Runtime images don't contain a shell. Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to running containers for inspection. |

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers.

### Permissions

This image runs as root (UID 0) and requires `CAP_NET_ADMIN`. This matches the upstream image's privilege requirements —
no changes are needed for the security context when using the Z2JH Helm chart.

### Entry point

Docker Hardened Images may have different entry points than upstream images. Use `docker inspect` to inspect entry
points and update your deployment if necessary.
