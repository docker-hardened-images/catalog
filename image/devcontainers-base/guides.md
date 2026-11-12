## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Dev Containers Base image

This image is a development container base. It is published only as a `dev` variant, because an IDE needs a shell and a
package manager to attach to the container. Replace `<tag>` with the image variant you want to run.

```bash
docker run -it --rm dhi.io/devcontainers-base:<tag>-dev
```

The container starts as `root`, as the upstream image does. It also contains a `vscode` user (uid and gid `1000`) with
passwordless `sudo`, bash and zsh configured with the Dev Containers prompt, and Oh My Zsh. The image metadata selects
`vscode` as the remote user, so dev container tools connect as that user. To start a shell as `vscode` yourself, use
`-u vscode`.

```bash
docker run -it --rm -u vscode dhi.io/devcontainers-base:<tag>-dev
```

## Common Dev Containers Base use cases

### Use the image in a devcontainer.json

Reference the image. The metadata baked into the image sets `vscode` as the remote user. Add the runtimes and tools your
project needs with [dev container features](https://containers.dev/features).

```json
{
  "image": "dhi.io/devcontainers-base:<tag>-dev",
  "features": {
    "ghcr.io/devcontainers/features/node:1": {}
  }
}
```

### Add a language runtime in a Dockerfile

The image contains no language runtime. Install what you need on top of it, using `apt-get` on the Debian variants or
`apk` on the Alpine variants.

```dockerfile
FROM dhi.io/devcontainers-base:<tag>-dev
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-venv
USER vscode
```

## Non-hardened images vs. Docker Hardened Images

The image is built to behave like the upstream dev container base image. These are the differences.

| Item              | Upstream dev container base image                               | Docker Hardened Image                                                                                                                                   |
| :---------------- | :-------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Git               | Built from source into `/usr/local/bin/git`                     | The operating system package, at `/usr/bin/git`.                                                                                                        |
| Build tools       | `gcc`, `make` and C headers remain installed after building Git | Not included. Install what you need with `apt-get` or `apk`.                                                                                            |
| Oh My Zsh         | Installed as a Git checkout in each home directory              | Installed from a package, read-only under `/usr/share/oh-my-zsh` and linked from `~/.oh-my-zsh`. Custom themes and plugins go in `~/.oh-my-zsh-custom`. |
| Operating systems | Debian, Ubuntu and Alpine                                       | Debian 13 and Alpine 3.24.                                                                                                                              |
| Variants          | One image                                                       | Published only as `dev` variants.                                                                                                                       |

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
