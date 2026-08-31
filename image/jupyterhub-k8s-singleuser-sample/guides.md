## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Replace `<version>` in all commands with the desired image version (for example, `4.4.0`).

This image provides the JupyterLab single-user notebook server used by
[Zero to JupyterHub on Kubernetes](https://z2jh.jupyter.org/) (Z2JH). When JupyterHub spawns a session for a user, it
launches a pod running this image. For full spawner configuration, see the
[Z2JH configuration reference](https://z2jh.jupyter.org/en/stable/resources/reference.html).

### What's included in this JupyterHub K8s Singleuser Sample image

This Docker Hardened Image ships the JupyterLab single-user server with `nbgitpuller` and `nbclassic` extensions,
installed in a self-contained virtual environment at `/opt/singleuser/.venv`. The `tini` init process manager is present
at `/usr/bin/tini`. Port **8888** is the default JupyterLab listen port.

## Start JupyterHub K8s Singleuser Sample

Run the container and open JupyterLab in your browser:

```console
docker run --rm -p 8888:8888 dhi.io/jupyterhub-k8s-singleuser-sample:<version>-debian13
```

Then open `http://localhost:8888` in your browser. By default a token is required for authentication. To disable the
token for local testing only, pass `--ServerApp.token=`:

```console
docker run --rm -p 8888:8888 dhi.io/jupyterhub-k8s-singleuser-sample:<version>-debian13 \
  jupyter lab --ip 0.0.0.0 --ServerApp.token=
```

### Use with Zero to JupyterHub on Kubernetes

Configure the Z2JH Helm chart to use this image for single-user pods:

```yaml
singleuser:
  image:
    name: dhi.io/jupyterhub-k8s-singleuser-sample
    tag: <version>-debian13
  podSecurityContext:
    fsGroup: 100
  containerSecurityContext:
    runAsUser: 1000
    runAsGroup: 100
```

The chart default targets the upstream image which also runs as UID 1000 (jovyan), so the security context values above
match the upstream convention.

### Verify the image

Check which JupyterLab version is installed:

```console
docker run --rm \
  --entrypoint /opt/singleuser/.venv/bin/jupyter \
  dhi.io/jupyterhub-k8s-singleuser-sample:<version>-debian13 \
  lab --version
```

### Environment variables

| Variable             | Description                                   |
| -------------------- | --------------------------------------------- |
| `JUPYTERLAB_VERSION` | JupyterLab application version in this image. |

### Paths and ports

| Path                    | Purpose                                                    |
| ----------------------- | ---------------------------------------------------------- |
| `/home/jovyan`          | Working directory and home for the jovyan user.            |
| `/opt/singleuser/.venv` | Python virtual environment with JupyterLab and extensions. |
| `8888/tcp`              | Default JupyterLab listen port.                            |

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Topic | `quay.io/jupyterhub/k8s-singleuser-sample` (upstream) | This image                                                                 |
| ----- | ----------------------------------------------------- | -------------------------------------------------------------------------- |
| Base  | Upstream-built image                                  | Minimal Debian-based hardened runtime                                      |
| User  | jovyan (UID 1000, GID 100)                            | jovyan (UID **1000**, GID **100**); same as upstream                       |
| Shell | Includes bash and system tools                        | Runtime image has no shell; use **Docker Debug** for inspection            |
| Entry | `tini` plus `jupyter lab`                             | `tini` plus `jupyter lab --ip 0.0.0.0` (see **Start the notebook server**) |

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

To migrate your application to a Docker Hardened Image, update your Kubernetes manifests to reference this image.

| Item               | Migration note                                                                                                                                                |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace upstream image references with the Docker Hardened Image tag.                                                                                         |
| Package management | Runtime images don't contain package managers. Use dev-tagged images for build stages.                                                                        |
| Non-root user      | Runtime images run as `nonroot` (UID 65532) by default. This image uses jovyan (UID 1000) matching upstream; adjust `podSecurityContext` accordingly.         |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default.                                                                                          |
| Entry point        | Docker Hardened Images may have different entry points than upstream images. Inspect entry points and update your deployment if necessary.                    |
| No shell           | Runtime images don't contain a shell. Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to running containers for inspection. |

## Troubleshoot migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default, image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
