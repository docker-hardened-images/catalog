## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/linkerd-tap:<tag>`
- Mirrored image: `<your-namespace>/dhi-linkerd-tap:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a linkerd-tap image

Linkerd starts this image for you. The Linkerd viz Helm chart runs it as the `tap` container and the `tap-injector`
container. The tap deployment's arguments start with `api`. The injector deployment's arguments start with `injector`.
Both need the certificates and kubeconfig the chart mounts, so the commands in this guide only print the release or show
what happens with no subcommand.

The entrypoint is `/tap`, the same path as the upstream image. `/tap` is a symbolic link to `/usr/bin/linkerd-tap`.

`api` serves the tap API over HTTPS on port 8089. Clients present a certificate, and the listener uses TLS 1.3. Its HTTP
admin server listens on port 9998. `/ping` is the liveness check and `/ready` is the readiness check.

`injector` serves the tap injector webhook on port 8443. Its HTTP admin server listens on port 9995, with `/ping` for
liveness and `/ready` for readiness.

The viz chart also declares container port 8088, named `grpc`. This binary does not listen on port 8088.

### Use the image with the Linkerd viz Helm chart

Install the Linkerd control plane as described in the
[Linkerd installation guide](https://linkerd.io/2/getting-started/). Then set the viz chart's tap images. The tap
deployment reads `tap.image.registry`, `tap.image.name`, and `tap.image.tag`. The injector deployment reads
`tapInjector.image.registry`, `tapInjector.image.name`, and `tapInjector.image.tag`. Set both `registry` values to
`dhi.io`, both `name` values to `linkerd-tap`, and both `tag` values to the tag you want (`<tag>` in this guide).

Both `name` values default to `tap`. An empty `registry` uses `defaultRegistry`, `cr.l5d.io/linkerd`. An empty `tag`
uses the chart's `linkerdVersion`, an `edge-<version>` release, which is also a tag of this image. Set
`imagePullSecrets` when the cluster pulls from `dhi.io` with a pull secret.

The image user is UID 65532 and GID 65532. The chart's `defaultUID` and `defaultGID` are 2103, and the tap and
tap-injector deployments use those values for `runAsUser` and `runAsGroup` unless they are overridden. Set `tap.UID` and
`tap.GID` to 65532, and set `tapInjector.UID` and `tapInjector.GID` to 65532, in the same values as the registry, name,
and tag overrides. Both containers then run as the image user.

### Check the packaged release

`api -version` and `injector -version` print the Linkerd release:

```bash
$ docker run --rm dhi.io/linkerd-tap:<tag> api -version
edge-<version>
```

```bash
$ docker run --rm dhi.io/linkerd-tap:<tag> injector -version
edge-<version>
```

### Run without a subcommand

With no arguments the process prints `expected a subcommand` and exits 1:

```bash
$ docker run --rm dhi.io/linkerd-tap:<tag>
```

## Non-hardened images vs. Docker Hardened Images

- The image runs as the nonroot user, UID and GID 65532, where the upstream image runs as root unless the pod sets a
  user. The viz chart's default UID and GID are 2103. Set `tap.UID`, `tap.GID`, `tapInjector.UID`, and `tapInjector.GID`
  to 65532 so both deployments run as the image user.
- The entrypoint is `/tap`, the upstream path. The binary is also at `/usr/bin/linkerd-tap`.
- `api -version` and `injector -version` print the Linkerd release, for example `edge-<version>`, from
  `LINKERD_CONTAINER_VERSION_OVERRIDE`. The upstream image leaves that variable unset and prints `dev-undefined`.
- The Apache-2.0 license is at `/linkerd/LICENSE`, the same path as the upstream image.
- This binary does not listen on port 8088. The viz chart's container port of that number, named `grpc`, has no listener
  in the tap or injector process.
- The runtime variants contain no shell. Use the dev variants, or Docker Debug, to get one.

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
