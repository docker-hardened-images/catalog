## How to use this image

`dhi/miniconda3` is a **dev-only** image — it runs as `root`, ships a `bash` shell and `apt`, and is intended as a
build-time base for a downstream image (typically in a multi-stage `Dockerfile`). Use the dev image to install your
conda environment, then copy `/opt/conda` (or a subset) into a hardened runtime image of your choice.

`conda` and `python` are on `PATH` (`/opt/conda/bin` is prepended), so they can be invoked directly.

## Start a Miniconda3 container

Open an interactive shell in the latest dev image:

```bash
docker run --rm -it dhi/miniconda3:26-debian13-dev
```

You'll land in a `bash` prompt with `conda` and `python` already on `PATH`.

Run a one-off command:

```bash
docker run --rm dhi/miniconda3:26-debian13-dev conda --version
docker run --rm dhi/miniconda3:26-debian13-dev python --version
docker run --rm dhi/miniconda3:26-debian13-dev conda list
```

## Common use cases

### Install conda packages in a one-off container

```bash
docker run --rm -it dhi/miniconda3:26-debian13-dev bash -c \
  "conda install -y -n base scikit-learn pandas && python -c 'import sklearn, pandas; print(sklearn.__version__, pandas.__version__)'"
```

`conda install` writes to `/opt/conda`, which is owned by `root`. Because the dev image runs as `root` this works out of
the box.

### Multi-stage build: install a conda env then ship the result

The intended pattern for production use:

```Dockerfile
# Build stage — full Miniconda3 with apt + bash.
FROM dhi/miniconda3:26-debian13-dev AS build

# Install your env into /opt/conda. Use --solver=libmamba for speed when you have many deps.
RUN conda install -y -n base \
        numpy \
        pandas \
        scikit-learn \
    && conda clean --all --yes

# Optional: pip-install anything that isn't on conda-forge.
RUN /opt/conda/bin/pip install --no-cache-dir python-dotenv

# Runtime stage — bring your own hardened Python or distroless base.
FROM dhi/python:3.13-debian13

COPY --from=build /opt/conda /opt/conda
ENV PATH=/opt/conda/bin:$PATH

USER nonroot
ENTRYPOINT ["python"]
CMD ["-c", "print('ready')"]
```

The runtime stage is whatever hardened image fits your application — `dhi/miniconda3` is not designed to be the runtime
itself.

### Copy a per-environment subset into another image

If you only need a single named environment (rather than `/opt/conda` in its entirety), create one in the build stage
and copy just that path:

```Dockerfile
FROM dhi/miniconda3:26-debian13-dev AS build
RUN conda create -y -n app python=3.13 numpy pandas && conda clean --all --yes

FROM dhi/python:3.13-debian13
COPY --from=build /opt/conda/envs/app /opt/conda/envs/app
ENV PATH=/opt/conda/envs/app/bin:$PATH
USER nonroot
CMD ["python", "-V"]
```

## What's included

- **`conda`**: The conda package and environment manager (`/opt/conda/bin/conda`). Use it to install packages, create
  named envs, and manage channels.
- **`python`**: Python interpreter bundled with the Miniconda installer (`/opt/conda/bin/python`). Tracks whichever
  CPython release Anaconda packages with the current installer (currently 3.13 for `26.x`).

Plus apt packages mirroring upstream `continuumio/miniconda3` (`bash`, `bzip2`, `ca-certificates`, `git`,
`libglib2.0-0t64`, `libsm6`, `libxext6`, `libxrender1`, `mercurial`, `openssh-client`, `procps`, `subversion`, `wget`),
plus `coreutils`, `findutils`, and `curl`.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

`dhi/miniconda3` is shipped **only as a dev variant** because the use cases for a no-shell, nonroot Miniconda runtime
(conda is a package manager that needs write access to `/opt/conda`) are vanishingly small. The dev variant:

- Runs as `root`
- Includes a `bash` shell and the `apt` package manager
- Ships the standard apt dependencies declared by `continuumio/miniconda3` upstream (`bzip2`, `git`, `libglib2.0-0t64`,
  `libsm6`, `libxext6`, `libxrender1`, `mercurial`, `openssh-client`, `procps`, `subversion`, `wget`)

This is the same family of "dev-only toolchain image" as `dhi/composer`, `dhi/gradle`, `dhi/maven`, and `dhi/openjdk`.

## Migrate to a Docker Hardened Image

If you currently use `continuumio/miniconda3`, swap the image reference:

```diff
- FROM continuumio/miniconda3:latest
+ FROM dhi/miniconda3:26-debian13-dev
```

Behaviour is the same — `root` user, `/bin/bash` `CMD`, `conda` and `python` on `PATH`, `/opt/conda` writable. The
hardened image additionally bakes an SPDX SBOM under `/opt/docker/sbom/` so downstream Scout scans see the bundled conda
packages.

## Troubleshooting migration

### General debugging

Inspect what's installed:

```bash
docker run --rm dhi/miniconda3:26-debian13-dev conda list
```

Check the bundled Python interpreter and OpenSSL it links against:

```bash
docker run --rm dhi/miniconda3:26-debian13-dev python -c "import ssl; print(ssl.OPENSSL_VERSION)"
```

### FIPS

`dhi/miniconda3` does **not** offer a FIPS variant. The Miniconda installer bundles its own OpenSSL into
`/opt/conda/lib/`; Python in conda links against that copy, not the system OpenSSL. A system-level FIPS swap would not
make conda's runtime crypto FIPS-validated. See the **A note on FIPS** section of `overview.md` for the full rationale.

### conda channels

This image defaults to **conda-forge** with `channel_priority: strict` (configured in `/opt/conda/.condarc`), so
`conda install <pkg>` works out of the box. Anaconda's default channels (`pkgs/main`, `pkgs/r`) now reject
non-interactive use with `CondaToSNonInteractiveError`, which breaks `conda install` in Docker/CI builds — conda-forge
is the open, ToS-free standard and avoids that entirely.

If you specifically need Anaconda's `defaults` channels, you must first accept Anaconda's commercial Terms of Service
with `conda tos accept` before installing from them.

### Upstream deprecation note

Anaconda has announced that `continuumio/miniconda3` will be discontinued **after upstream version `26.7.x`**, with new
images published as `anaconda/miniconda`. This DHI definition will track the deprecation: once Anaconda stops releasing
under `miniconda3-*` tags, this image will be re-pointed at the `anaconda/miniconda` upstream (or deprecated alongside
it).
