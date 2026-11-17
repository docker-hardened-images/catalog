## How to use this image

The Haskell image provides GHC, `ghci`, `ghc-pkg`, `cabal`, and `stack` on Debian 13 and Alpine 3.24. Both runtime and
dev images include the C toolchain and development libraries needed for compilation and the REPL. Runtime images print
the GHC version by default. Dev images start a shell and add a system package manager.

Examples use the public registry. Authenticate with `docker login dhi.io`, or substitute your mirrored image reference.

### What's included

| Tool      | Description                                  |
| :-------- | :------------------------------------------- |
| `ghc`     | The Glasgow Haskell Compiler                 |
| `ghci`    | The interactive GHC environment              |
| `ghc-pkg` | The GHC package manager                      |
| `cabal`   | Command-line interface for Cabal and Hackage |
| `stack`   | The Haskell Tool Stack                       |

The image also includes GCC, G++, make, Git, curl, GnuPG, tar, xz, and development headers for the C library, GMP,
libffi, NUMA, ncurses, and zlib. GHC's Haddock API documentation, HTML guides, PDFs, manpage, and profiling libraries
are retained. The installed tools are on `PATH`; Cabal's and Stack's user-installed executables under `$HOME/.cabal/bin`
and `$HOME/.local/bin` take precedence.

### Start a Haskell REPL

`ghci`, `runghc`, and native compilation work in both variants:

```console
$ docker run --rm -it dhi.io/haskell:9.14-debian13 ghci
$ docker run --rm -it dhi.io/haskell:9.14-alpine3.24 ghci
```

### Build a Haskell application

Use the same distribution in the build and runtime stages. Alpine uses musl; Debian uses glibc. Do not copy a
Debian-built executable into an Alpine image or assume a Haskell executable is fully static.

For a downstream application's Dockerfile, this self-contained example builds a small program and runs it as the runtime
image's non-root user. Both stages retain the Haskell toolchain; the final stage omits root access and the system
package manager, not the compiler:

```dockerfile
# syntax=docker/dockerfile:1

FROM dhi.io/haskell:9.14-alpine3.24-dev AS build
WORKDIR /src
RUN printf 'main :: IO ()\nmain = putStrLn "hello-haskell"\n' > Main.hs \
    && ghc Main.hs -o /src/app

FROM dhi.io/haskell:9.14-alpine3.24
COPY --from=build /src/app /usr/local/bin/app
ENTRYPOINT ["/usr/local/bin/app"]
```

For Debian, change both tags to `9.14-debian13-dev` and `9.14-debian13`. Applications with additional native
dependencies need those libraries in the final image too.

### Use cabal and Stack

Both build tools work in runtime and dev variants. The source directory and build caches must be writable by the
container user. Use a `-dev` tag when installing additional system dependencies. Cabal uses the GHC on `PATH`.

Stack defaults to `system-ghc: true` and `install-ghc: false`, matching the Docker Official Image. These defaults live
in `/etc/stack/config.yaml` and can be overridden in your project or user configuration. Select a resolver compatible
with the installed GHC, such as `resolver: ghc-9.14.1`, to use the bundled compiler without downloading another one.

## Non-hardened images vs. Docker Hardened Images

The Docker Official Image starts `ghci` and runs as root. Here, both variants default to `ghc --version`, the runtime as
user 65532 and the dev variant as root. Invoke `ghci` explicitly. Neither variant defines an entrypoint, so commands
such as `ghc`, `cabal`, and `stack` can be passed directly.

Both distributions retain the development toolchain, like the official Haskell and Haskell slim images. Runtime variants
omit the system package manager. Debian packaging utilities (`dpkg-dev`) are available only in the dev variant. Alpine
uses musl and equivalent Alpine packages rather than Debian's glibc packages. `cabal` and `stack` follow their own
upstream releases rather than the versions the Docker Official Image pins for this GHC line, so either can differ from
the official image at the same tag.

`stack --version` reports an unsupported build and suggests `stack upgrade --force-download`. Stack is built from source
here rather than repackaged from an official release binary, and upstream asks distributors who build through Cabal to
leave that notice in place, so it is expected and does not indicate a problem. Do not run `stack upgrade`: it replaces
the image's Stack with an upstream download that carries none of this image's provenance. Pin a Stack version by using
the matching image tag instead.

### Runtime variant exception

Unlike typical Docker Hardened runtime variants, both Haskell runtime images retain a shell for GHC's wrappers, the C
toolchain, development headers, and build helpers. These are complete Haskell toolchain images, not compiler-free
application runtime images. Use matching Debian or Alpine distributions across build and runtime stages; Haskell
executables are not necessarily fully static. This exception takes precedence over the standardized guidance below about
runtime images not containing a shell or build tools.

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
