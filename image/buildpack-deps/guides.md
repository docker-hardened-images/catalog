## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-buildpack-deps:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this buildpack-deps image

This Docker Hardened buildpack-deps image includes:

- A C/C++ toolchain: `gcc`, `g++`, `make`, `autoconf`, `libtool`, `patch`, `file`
- Source control clients: `git`, `mercurial`, `subversion`, `openssh-client`
- Fetch and verify tools: `curl`, `wget`, `gpg`
- Development headers, including OpenSSL, PostgreSQL, MariaDB client, SQLite, GLib, readline, ncurses, libxml2, libxslt,
  libyaml, libffi, zlib, bzip2, lzma, Kerberos, libevent, GDBM, GMP, MaxMindDB, and the JPEG, PNG, and WebP image
  libraries

## Start a buildpack-deps image

The image starts a `bash` shell by default. Replace `<tag>` with the image variant you want to run.

### Basic usage

```bash
$ docker run --rm -it dhi.io/buildpack-deps:<tag>
```

Check the toolchain:

```bash
$ docker run --rm dhi.io/buildpack-deps:<tag> gcc --version
```

## Common buildpack-deps use cases

### Build stage of a multi-stage Dockerfile

buildpack-deps is most useful as a build stage. Compile your application against the headers it provides, then copy the
result into a minimal runtime image.

```dockerfile
# syntax=docker/dockerfile:1
FROM dhi.io/buildpack-deps:<tag>-dev AS build

WORKDIR /src
COPY . .
RUN ./configure && make

FROM dhi.io/debian-base:<tag>
COPY --from=build /src/myapp /usr/local/bin/myapp
CMD ["/usr/local/bin/myapp"]
```

### Compiling a native extension

The development headers let language package managers build native extensions without extra setup:

```bash
$ docker run --rm dhi.io/buildpack-deps:<tag>-dev bash -c \
    "apt-get update && apt-get install -y python-3.13-dev && python3 -m ensurepip && python3 -m pip install --break-system-packages psycopg2"
```

### Checking out sources

```bash
$ docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" -w /work dhi.io/buildpack-deps:<tag> \
    git clone --depth 1 https://github.com/docker-library/buildpack-deps.git
```

## Non-hardened images vs. Docker Hardened Images

Upstream `buildpack-deps:trixie` installs a set of packages from the Debian archive. This hardened image installs the
same set from the Docker hardened package repository. A few upstream packages have no hardened equivalent yet and are
not included:

| Package                                                 | Why it is not included                                                                |
| :------------------------------------------------------ | :------------------------------------------------------------------------------------ |
| `imagemagick`, `libmagickcore-dev`, `libmagickwand-dev` | No hardened ImageMagick package exists                                                |
| `automake`                                              | No hardened package yet. `autoconf` and `libtool` are included                        |
| `dpkg-dev`                                              | No hardened package yet, so `dpkg-buildflags` and `dpkg-architecture` are not present |
| `sq`                                                    | No hardened Sequoia CLI package. `gpg` and `gpgv` are included                        |

If your build needs one of these, install it in a `dev` variant with `apt-get`, or add the build step to a stage that
uses the upstream image.

Upstream also publishes `curl` and `scm` tag variants that carry a smaller subset of these packages. This hardened image
matches the default (full) variant only.

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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

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
