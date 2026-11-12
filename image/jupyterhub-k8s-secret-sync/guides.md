## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image provides the secret-sync sidecar used by [Zero to JupyterHub on Kubernetes](https://z2jh.jupyter.org/)
(Z2JH). It reads a file (typically `acme.json`) from an emptyDir volume and syncs its contents to a Kubernetes Secret so
that ACME certificates issued by Traefik survive proxy pod restarts.

### What's included in this JupyterHub K8s Secret Sync image

This Docker Hardened Image ships the `acme-secret-sync` Python script at `/usr/bin/acme-secret-sync`, backed by a
self-contained virtual environment at `/opt/acme-secret-sync/.venv`. The `tini` init process manager is present at
`/usr/bin/tini`.

## Start JupyterHub K8s Secret Sync

To confirm the image is functional, run the built-in help. Replace `<version>` with the desired version tag:

```console
docker run --rm \
  dhi.io/jupyterhub-k8s-secret-sync:<version> \
  --help
```

### Use with Zero to JupyterHub on Kubernetes

Deploy the Z2JH Helm chart and configure the proxy's secret-sync sidecar to use this image. Set
`proxy.secretSync.image.name` and `proxy.secretSync.image.tag`:

```yaml
proxy:
  secretSync:
    image:
      name: dhi.io/jupyterhub-k8s-secret-sync
      tag: <version>
```

Replace `<version>` with the desired version (see the Tags tab for this repository).

The chart defaults assume the upstream image runs as root. This Docker Hardened Image runs as the `nonroot` user
(**65532** / **65532**). Override the sidecar security context to match:

```yaml
proxy:
  secretSync:
    containerSecurityContext:
      runAsUser: 65532
      runAsGroup: 65532
      runAsNonRoot: true
```

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Topic | `quay.io/jupyterhub/k8s-secret-sync` (upstream) | `dhi.io/jupyterhub-k8s-secret-sync` (this image) |
| ----- | ----------------------------------------------- | ------------------------------------------------ |
| Base  | Alpine-based upstream image                     | Minimal Debian-based hardened runtime            |
| User  | Runs as root                                    | `nonroot` (65532); adjust chart security context |
| Shell | Includes shell                                  | Runtime image has no shell; use Docker Debug     |
| Entry | tini + acme-secret-sync                         | tini + acme-secret-sync (parity)                 |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
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

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate to this Docker Hardened Image, override the sidecar image references in your Zero to JupyterHub Helm chart
values file.

| Item               | Migration note                                                                                                                                                |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace upstream image references with the Docker Hardened Image tag.                                                                                         |
| Package management | Runtime images don't contain package managers. Use dev-tagged images for debugging only.                                                                      |
| Non-root user      | This image runs as `nonroot` (UID 65532). Update the sidecar security context in the chart values.                                                            |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default.                                                                                          |
| Entry point        | Docker Hardened Images may have different entry points than upstream images. Inspect entry points and update your deployment if necessary.                    |
| No shell           | Runtime images don't contain a shell. Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to running containers for inspection. |

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers.

### Permissions

By default image variants intended for runtime run as the `nonroot` user (UID 65532). Ensure that necessary files and
directories are accessible. If the chart security context does not set `runAsUser: 65532`, the sidecar process may fail
to start.

### Entry point

Docker Hardened Images may have different entry points than upstream images. Use `docker inspect` to inspect entry
points and update your deployment if necessary.
