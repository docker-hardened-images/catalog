## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/datascience-notebook:<tag>`
- Mirrored image: `<your-namespace>/dhi-datascience-notebook:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Jupyter Data Science Notebook image

This Docker Hardened Jupyter Data Science Notebook image includes:

| Tool      | Purpose                                                             |
| --------- | ------------------------------------------------------------------- |
| `jupyter` | JupyterLab + classic Notebook frontends, `jupyterhub-singleuser`    |
| `python`  | Python 3.13 with scipy, pandas, scikit-learn, matplotlib, dask, ... |
| `R`       | R with tidyverse, tidymodels, caret, IRkernel, rpy2                 |
| `julia`   | Julia 1.12 with IJulia, HDF5, Pluto                                 |
| `mamba`   | Fast conda CLI for installing additional conda-forge packages       |
| `conda`   | The full conda CLI for env/package management                       |
| `pandoc`  | Document conversion engine for `jupyter nbconvert`                  |

## Start a Jupyter Data Science Notebook image

### Basic usage

Run the container, exposing the notebook port and mounting a working directory for your notebooks:

```bash
docker run --rm -it \
  -p 8888:8888 \
  -v "$(pwd)":/home/jovyan/work \
  dhi.io/datascience-notebook:<tag>
```

The container starts JupyterLab on port 8888. The startup logs include a URL with a one-time token; open it in a browser
to access the UI.

### Set a known token (development only)

To pre-set the token (only safe on a trusted local machine), set `JUPYTER_TOKEN`:

```bash
docker run --rm -it \
  -p 8888:8888 \
  -e JUPYTER_TOKEN=mytoken \
  dhi.io/datascience-notebook:<tag>
```

Then connect to `http://localhost:8888/?token=mytoken`.

### Open a shell inside the notebook environment

Override the entrypoint to drop into a bash shell with the conda environment activated:

```bash
docker run --rm -it \
  --entrypoint /bin/bash \
  dhi.io/datascience-notebook:<tag>
```

You can then run `python`, `R`, or `julia` directly.

### Use as a JupyterHub single-user image

This image bundles `jupyterhub-singleuser` so a JupyterHub deployment can spawn it as a per-user notebook server.
Configure JupyterHub's spawner to point at this image rather than running the binary directly. Running
`jupyterhub-singleuser` standalone exits immediately because the binary requires `JUPYTERHUB_SERVICE_URL` and related
environment variables that JupyterHub itself sets when spawning. See the
[JupyterHub documentation on Docker spawners](https://jupyterhub.readthedocs.io/en/stable/reference/spawners.html) for
configuration.

## Common Jupyter Data Science Notebook use cases

### Persisting notebooks to a host directory

Mount your working directory into `/home/jovyan/work`. The container runs as UID 1000, GID 100; make sure the host
directory is writable by that UID/GID, or chown it before mounting.

```bash
mkdir -p notebooks
sudo chown -R 1000:100 notebooks
docker run --rm -it \
  -p 8888:8888 \
  -v "$(pwd)/notebooks":/home/jovyan/work \
  dhi.io/datascience-notebook:<tag>
```

### Exporting notebooks with `nbconvert`

The image ships `pandoc`, so `jupyter nbconvert` can produce HTML, Markdown, and reStructuredText output:

```bash
docker run --rm \
  -v "$(pwd)":/home/jovyan/work \
  dhi.io/datascience-notebook:<tag> \
  jupyter nbconvert --to html /home/jovyan/work/analysis.ipynb
```

PDF export via `--to pdf` is not supported; it requires a TeX Live distribution which is not bundled in this image. Use
the upstream image for PDF export, or export to HTML and print to PDF from a browser.

## Non-hardened images vs. Docker Hardened Images

Some upstream conveniences are not carried over in the hardened image:

| Feature                   | Upstream (`quay.io/jupyter/datascience-notebook`)  | DHI (`dhi.io/datascience-notebook`)                         |
| ------------------------- | -------------------------------------------------- | ----------------------------------------------------------- |
| Base                      | `ubuntu:24.04`                                     | Debian 13 (static, distroless-style)                        |
| Package source            | conda-forge (Python, R), julialang.org (Julia)     | Same, with SHA-pinned binaries                              |
| Reproducibility           | Pulls `micromamba latest`, `julia stable` at build | Pinned `MICROMAMBA_VERSION` and `JULIA_VERSION` with SHA256 |
| SBOM                      | Not published                                      | Embedded SPDX for all installed conda + system packages     |
| Default user              | `jovyan` (UID 1000, GID 100)                       | Same                                                        |
| Entrypoint                | `tini -g -- start.sh`                              | Same                                                        |
| Default command           | `start-notebook.py`                                | Same                                                        |
| `RESTARTABLE` opt-in mode | Supported via the `run-one` apt package            | Not supported. Setting `RESTARTABLE=yes` will fail to spawn |
| PDF export (`nbconvert`)  | TeX Live bundled, `--to pdf` works                 | Not bundled, use `--to html` instead                        |
| Build tools (gcc, etc.)   | Available via apt at runtime                       | Not in runtime; use a separate build stage                  |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

A `-dev` variant is published for use as a build stage in multi-stage Dockerfiles. It runs as root and ships `apt` so
that downstream `RUN` steps can install additional system packages or compile Python/R extensions from source. The
runtime variant is itself usable for interactive notebook customization since it already carries `conda`, `mamba`,
`pip`, and `bash`.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

### Data Science Notebook-specific migration notes

- **Notebook UI:** The default frontend is JupyterLab at `/lab`. The legacy classic Notebook UI at `/tree` is still
  available through `nbclassic` but is not the default; some upstream tutorials that reference the `/tree` URL still
  apply if you visit that path directly.
- **Adding packages:** Use `mamba install -c conda-forge <pkg>` for conda packages, `pip install --user <pkg>` for
  Python-only packages, or `Pkg.add` in Julia. The runtime is read-only outside `/home/jovyan`, so `--user` installs go
  to `/home/jovyan/.local`.
- **First-import Julia delay:** Julia package precompilation is performed lazily on first import (a known build-time
  issue with `Pkg.precompile()` in this image, documented in the `KNOWN-ISSUE` block in the build pipeline). Expect a
  ~30s one-time stall on the first `using` of each package, then normal speed afterward.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
