## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this r-base image

This Docker Hardened r-base image includes:

- `R` — the R interpreter and interactive console.
- `Rscript` — front end for running R scripts and one-liners non-interactively.
- The recommended packages that ship with the upstream R release, including `MASS`, `Matrix`, `lattice`, `survival`,
  `boot`, `nlme`, `cluster`, and `rpart`. Unlike Debian's packaging, which splits these into separate `r-cran-*`
  packages, they are installed with the interpreter.
- `r` — littler, for running R from the command line and in `#!` scripts.
- `install.r`, `install2.r`, `installBioc.r`, `installDeps.r`, `installGithub.r`, and `testInstalled.r` — littler's
  helper scripts, available on `PATH` from `/usr/local/bin`.
- OpenBLAS, so linear algebra is multithreaded rather than falling back to reference BLAS.
- Cairo-backed bitmap and SVG devices (`png()`, `jpeg()`, `tiff()`, `svg()`), plus R's native `pdf()` and X11 devices.
- Tcl/Tk support, so `capabilities("tcltk")` is `TRUE` and CRAN packages that depend on `tcltk` install normally.

As on any headless Linux host, `library(tcltk)` loads and Tcl works, but Tk itself is only initialized when a `DISPLAY`
is set, so `tktoplevel()` and other widget calls need an X server or X forwarding. For the same reason
`capabilities("X11")` reports `FALSE` without a display even though the X11 device is built in. Both behaviors match
upstream `r-base` on the same R release.

## Start an r-base image

Print the R version to confirm the image runs:

```console
$ docker run --rm dhi.io/r-base:<tag> R --version
```

The image's default command is `R`, which starts the interactive console. To use it interactively, allocate a TTY:

```console
$ docker run --rm -it dhi.io/r-base:<tag>
```

## Common r-base use cases

### Evaluate an expression without writing a file

`Rscript -e` runs R code straight from the command line, which is the quickest way to smoke-test the image or to run a
small calculation inside a pipeline.

```console
$ docker run --rm dhi.io/r-base:<tag> Rscript -e 'cat(sum(1:100), "\n")'
5050
```

### Run an analysis script from the host

Mount your script into the container and run it with `Rscript`. Use a working directory the nonroot user can read.

Given `analysis.R` in the current directory:

```r
data <- data.frame(x = 1:10, y = (1:10)^2)
fit <- lm(y ~ x, data = data)
cat("slope:", coef(fit)[["x"]], "\n")
```

Run it:

```console
$ docker run --rm -v "$PWD/analysis.R:/work/analysis.R:ro" -w /work \
    dhi.io/r-base:<tag> Rscript analysis.R
slope: 11
```

### Render a plot to a file

The image ships Cairo-backed graphics devices, so plotting needs no X server. Write the output to a mounted directory.
The runtime image runs as a nonroot user (UID 65532), so create the output directory first and run the container with
your host UID to keep the mounted directory writable:

```console
$ mkdir -p out
$ docker run --rm -u "$(id -u):$(id -g)" -v "$PWD/out:/out" dhi.io/r-base:<tag> \
    Rscript -e 'png("/out/plot.png", width = 800, height = 600); plot(1:10, (1:10)^2, type = "b"); dev.off()'
```

### Install CRAN packages in a build stage

Installing from CRAN compiles C, C++, and FORTRAN sources, so it needs the `dev` variant's toolchain. Use a multi-stage
build and copy the installed library into the runtime stage.

```dockerfile
FROM dhi.io/r-base:<tag>-dev AS build
RUN Rscript -e 'install.packages("jsonlite", repos = "https://cloud.r-project.org", lib = "/usr/local/lib/R/site-library")'

FROM dhi.io/r-base:<tag>
COPY --from=build /usr/local/lib/R/site-library /usr/local/lib/R/site-library
COPY analysis.R /work/analysis.R
WORKDIR /work
CMD ["Rscript", "analysis.R"]
```

For reproducible dependency management across a larger project, including lockfiles and per-project libraries, see the
[renv documentation](https://rstudio.github.io/renv/) and the
[CRAN package installation docs](https://cran.r-project.org/doc/manuals/r-release/R-admin.html#Installing-packages).

## Non-hardened images vs. Docker Hardened Images

This image is built from the upstream R release rather than from Debian's `r-base` source package, which leads to a few
differences from `r-base` and `rocker/r-base`:

- **Recommended packages are installed with the interpreter** rather than through a separate `r-recommended` package, so
  there is nothing extra to install for `MASS`, `Matrix`, and the rest.
- **`R_HOME` is `/usr/lib/R`**, matching upstream `r-base`. littler is available as `/usr/bin/r`, its helper scripts are
  reachable from `/usr/local/bin`, and `/usr/local/lib/R/site-library` is first on `R_LIBS_SITE`.
- **No `docker` user or `staff` group.** Upstream `r-base` adds a `docker` user in the `staff` group so that group can
  write to the site library. Runtime variants here run as the standard hardened nonroot user instead.
- **Runtime variants run as a nonroot user** and contain no package manager. Unlike most hardened runtime images they do
  ship a minimal shell (`/bin/sh`, dash): R's front end `/usr/lib/R/bin/R` is a POSIX shell script, so a shell is
  required for R to start at all. Use the `dev` variant for anything that installs packages or compiles code.
- **FIPS variants use the validated OpenSSL module for R's TLS network operations.** The HTTPS transport behind
  `download.file()` and `install.packages()` reaches OpenSSL through libcurl. R's built-in hashing functions, including
  `tools::md5sum()`, use R's bundled implementations and continue to work in FIPS variants.

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
