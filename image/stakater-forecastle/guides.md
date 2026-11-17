## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Forecastle is a Kubernetes control panel from Stakater. This image replaces `stakater/forecastle`. It watches Ingresses
and serves a launchpad UI for the applications it discovers. Project documentation is at
https://github.com/stakater/Forecastle.

Debian 13 tags include `2`, `2.0`, `2.0.2`, `2-debian13`, and `2.0.2-debian13`. Alpine 3.24 tags include `2-alpine3.24`
and `2.0.2-alpine3.24`. Alpine has no bare major tag. The commands below use `2.0.2-debian13`.

Debian 13 and Alpine 3.24 each publish runtime, dev, and FIPS variants. FIPS variants use the OpenSSL FIPS provider and
a Forecastle binary built with the Go FIPS module. FIPS tags include `2.0.2-debian13-fips` and `2.0.2-alpine3.24-fips`.

## Start a Forecastle image

The image does not contain a default config file. Save the following as `config.yaml` in the current directory:

```yaml
namespaceSelector:
  any: true
title: Forecastle
crdEnabled: false
```

`namespaceSelector.any: true` selects every namespace. `crdEnabled: false` leaves ForecastleApp custom resources out of
discovery.

Mount that file at `/etc/forecastle/config.yaml`. Also give the process a kubeconfig that uid 65532 can read. Mode
`0644` is enough. Set `KUBECONFIG` to the path inside the container. When `KUBECONFIG` is unset, the process reads
`$HOME/.kube/config`, which is `/home/nonroot/.kube/config` for this image. The API server address in the kubeconfig
must be reachable from the container.

Name the kubeconfig file `kubeconfig` and place it next to `config.yaml`.

```bash
$ chmod 644 config.yaml kubeconfig
```

```bash
$ docker run -d --name forecastle \
  -p 3000:3000 \
  -v "$(pwd)/config.yaml:/etc/forecastle/config.yaml:ro" \
  -e KUBECONFIG=/kubeconfig \
  -v "$(pwd)/kubeconfig:/kubeconfig:ro" \
  dhi.io/stakater-forecastle:2.0.2-debian13
```

The process listens on port 3000 (`--port`). Publish that port. The launchpad UI is at http://localhost:3000/. The
binary default and the Helm chart target port are both 3000.

```bash
$ curl -fsS http://localhost:3000/api/apps
```

The response is a JSON array of apps discovered from Ingresses annotated with `forecastle.stakater.com/expose=true`. The
annotation `forecastle.stakater.com/appName` sets the name shown for an app.

Upstream publishes port 3000 and mounts the same config file at `/etc/forecastle/config.yaml`. Outside a cluster, add
the kubeconfig mount from the example above.

## Non-hardened images vs. Docker Hardened Images

- The entrypoint is `/forecastle`, a symlink to the binary at `/usr/bin/forecastle`.
- The process runs as uid 65532 and gid 65532.
- The image declares port `3000/tcp`.
- `/etc/forecastle` is mode `0755` and owned by root (uid 0 and gid 0). The process does not write that directory, so
  the runtime user does not own it. A ConfigMap or bind mount at `/etc/forecastle/config.yaml` does not depend on who
  owns the parent directory. Upstream's image has no `/etc/forecastle` directory, and this image ships no default config
  file.
- `/home/nonroot` is mode `0700` and owned by uid 65532 and gid 65532.

## Troubleshooting

### No shell in the runtime image

Runtime tags ship without a shell or a package manager. Dev tags run as root and include a shell and a package manager.
The entrypoint is still `/forecastle`, so set `--entrypoint` to open a shell. On Debian, the dev tag
`2.0.2-debian13-dev` includes `bash`:

```bash
$ docker run --rm --entrypoint bash \
  dhi.io/stakater-forecastle:2.0.2-debian13-dev \
  -c 'ls -l /forecastle /usr/bin/forecastle'
```

The Alpine dev tag `2.0.2-alpine3.24-dev` includes `/bin/sh`.

### Missing configuration

When no config file is found, the process exits non-zero. It searches `/etc/forecastle`, `$HOME/.forecastle`, and the
working directory `/`.

### Kubeconfig permissions

When uid 65532 cannot read the kubeconfig, the process exits with status 1 and reports that it cannot open the file.
Mode `0644` is enough.

### Kubernetes API

The process contacts the Kubernetes API while it starts. The server address in the kubeconfig must be reachable from the
container. `127.0.0.1` in that file is the container itself, so use an address the container can open.

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
