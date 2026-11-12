## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use, update the commands
to reference your mirrored image instead.

For the examples, replace `<tag>` with the image tag you want to run. Common choices are `3`, `3-dev`, `3-fips`, and
`3-fips-dev`.

For more background on how Kubernetes uses the upstream `pause` image, see
[the upstream Kubernetes pause source tree](https://github.com/kubernetes/kubernetes/tree/master/build/pause).

## Start a Kubernetes pause container

The `kubernetes-pause` image is primarily intended for Kubernetes and other container runtimes that need a tiny
container to hold a namespace open. It is not typically run directly by end users, but you can start it locally to
verify behavior:

```console
$ docker run --rm -d --name kubernetes-pause-test dhi.io/kubernetes-pause:<tag>
```

## Check the embedded version

The upstream `pause` binary supports `-v`, which prints the embedded version and exits:

```console
$ docker run --rm dhi.io/kubernetes-pause:<tag> -v
```

## Stop the container

When you're done testing the image, stop and remove the container:

```console
$ docker rm -f kubernetes-pause-test
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Upstream `pause` image           | Docker Hardened `kubernetes-pause`     |
| --------------- | -------------------------------- | -------------------------------------- |
| Runtime content | Minimal static binary            | Minimal hardened runtime content       |
| User            | Non-root numeric user            | Non-root numeric user                  |
| Shell access    | No shell                         | No shell                               |
| Package manager | No package manager               | No package manager                     |
| Metadata        | Standard upstream image metadata | Hardened image metadata, SBOM, and VEX |

### Why no shell or package manager?

Docker Hardened Images prioritize minimal runtime content to reduce attack surface. The runtime image doesn't contain a
shell or package manager. Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) when you need to
inspect a running container.

## Use a dev variant for inspection

If you need an interactive shell or package manager for local inspection, use a dev variant and override the entrypoint
to `bash`:

```console
$ docker run --rm --entrypoint bash dhi.io/kubernetes-pause:3-dev -lc 'apt-get --version && locale'
```

The same pattern works for the FIPS-enabled dev image:

```console
$ docker run --rm --entrypoint bash dhi.io/kubernetes-pause:3-fips-dev -lc 'apt-get --version && locale'
```

## Migration context

`kubernetes-pause` is a special-purpose infrastructure container, so migration usually means updating the image
reference used by your Kubernetes distribution, sandbox configuration, or local test environment rather than using it as
a general application base image.

- Keep the default `/pause` entrypoint for runtime use.
- Do not expect a shell or package manager in the runtime or FIPS runtime variants.
- Use `dev` or `fips-dev` only when you need interactive inspection or debugging, and pair them with `--entrypoint bash`
  if you want a shell.
- If your environment already requires FIPS-oriented images, use the matching `-fips` or `-fips-dev` tag.

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
