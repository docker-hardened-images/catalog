## How to use this image

Docker Hardened Images are distributed from your organization's private mirror. Authenticate before pulling:

```bash
docker login dhi.io
```

Replace `<tag>` in the examples below with the image tag you want to run.

## Start a Rundeck instance

Rundeck serves its web console and REST API on port 4440. Start it with the embedded H2 database and open the console at
`http://localhost:4440`:

```bash
docker run --rm -p 4440:4440 \
  -e RUNDECK_GRAILS_URL=http://localhost:4440 \
  dhi.io/rundeck:<tag>
```

The default administrator credentials are `admin` / `admin`; change them before exposing the instance.

## Common Rundeck use cases

### Run behind an external URL

Rundeck needs to know the URL clients use to reach it so generated links and the web console resolve correctly. Set
`RUNDECK_GRAILS_URL` (and `RUNDECK_SERVER_FORWARDED=true` when running behind a reverse proxy):

```bash
docker run --rm -p 4440:4440 \
  -e RUNDECK_GRAILS_URL=https://rundeck.example.com \
  -e RUNDECK_SERVER_FORWARDED=true \
  dhi.io/rundeck:<tag>
```

### Persist jobs and logs across restarts

The embedded H2 database and execution logs live under `/home/rundeck/server/data` and `/home/rundeck/var/logs`. Mount
volumes to keep them across container restarts:

```bash
docker run --rm -p 4440:4440 \
  -e RUNDECK_GRAILS_URL=http://localhost:4440 \
  -v rundeck-data:/home/rundeck/server/data \
  -v rundeck-logs:/home/rundeck/var/logs \
  dhi.io/rundeck:<tag>
```

### Assign a stable server UUID for clustered deployments

In a cluster, each node needs a distinct, stable server UUID. Set `RUNDECK_SERVER_UUID=RANDOM` to generate one at first
start, or pass a fixed UUID:

```bash
docker run --rm -p 4440:4440 \
  -e RUNDECK_GRAILS_URL=http://localhost:4440 \
  -e RUNDECK_SERVER_UUID=RANDOM \
  dhi.io/rundeck:<tag>
```

For external datastores (MySQL/PostgreSQL), single sign-on, node executors, and plugin configuration, see the
[upstream Rundeck documentation](https://docs.rundeck.com/docs/).

## Non-hardened images vs. Docker Hardened Images

This image runs as a fixed non-root user and omits the build-time and privilege tooling (`sudo`, `gnupg2`, `wget`)
shipped by the upstream `rundeck/rundeck` image. The startup chain is preserved: the `remco` config templating step and
SSH-based node execution continue to work. Unlike upstream, the image does not support running under an arbitrary UID
(the OpenShift pattern): state directories are owned by the fixed non-root user rather than group-writable by GID 0.
Workflows that depend on the removed build/privilege tooling or on arbitrary-UID execution are not supported.

### Migrating from the upstream image

When replacing `rundeck/rundeck:<tag>` with `dhi.io/rundeck:<tag>`:

- Fix ownership on mounted volumes so the fixed non-root user (UID 65532) can write them:
  `chown -R 65532:65532 /host/path`.
- Set `RUNDECK_GRAILS_URL` to the URL clients use to reach the instance, and keep port `4440` available.
- If your deployment relies on arbitrary-UID execution (OpenShift), adjust it to run as the image's non-root user.
- If the container exits at startup, inspect the rendered configuration under `/home/rundeck/etc` and
  `/home/rundeck/server/config`, which the `remco` templating step writes from `RUNDECK_*` environment variables, and
  confirm mounted volumes are writable by the non-root runtime user.
- Rundeck extracts its bundled plugins into `/home/rundeck/libext` at startup and loads additional plugins from there.
  To add plugins, mount them into `/home/rundeck/libext` or bake them into a derived image; the directory must remain
  writable by the runtime user (UID 65532).

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
