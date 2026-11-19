## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Fleet Agent image

This image runs the `fleetagent` binary from `rancher/fleet`. Use it to replace `rancher/fleet-agent` in an existing
Fleet installation. The Fleet controller on the management cluster creates the agent deployment on each managed cluster,
so the usual way to use this image is to point the controller at it.

This image ships the Fleet `0.13`, `0.14`, `0.15` and `0.16` release lines. Use a minor tag such as `0.16`, or a full
tag such as `0.16.3`, to match the Fleet minor your controller runs; the `0` tag follows the newest minor. The
controller's default agent image carries the controller's own version. Upstream tags images with a leading `v` (for
example `v0.16.3`). The Debian tags publish both forms (`0.16.3` and `v0.16.3`), so a `v`-prefixed agent tag in an
existing configuration or an air-gap image list resolves without a change; the Alpine tags carry no `v`, so replace any
`v`-prefixed agent tag there.

Inspect the agent version:

```bash
$ docker run --rm dhi.io/fleet-agent:<tag> --version
```

The agent needs a Kubernetes API connection and a registration with a Fleet controller, so it is not meant to be run
standalone.

### Use the image with the Fleet Helm chart

Set the agent image in the values of the upstream `fleet` chart. The controller then deploys the agent from this image
on every cluster it manages, including the local cluster. Replace `<tag>` with the matching image tag and `<version>`
with the Fleet chart version.

```bash
$ helm repo add fleet https://rancher.github.io/fleet-helm-charts/
$ helm --namespace cattle-fleet-system install --create-namespace --wait fleet-crd fleet/fleet-crd --version <version>
$ helm --namespace cattle-fleet-system install --wait fleet fleet/fleet --version <version> --values values.yaml
```

```yaml
agentImage:
  repository: dhi.io/fleet-agent
  tag: <tag>
  imagePullPolicy: IfNotPresent
```

Managed clusters pull the agent from the registry you configure. On the Fleet `0.16` chart, supply credentials for
`dhi.io` through `global.cattle.imagePullSecrets` in the chart values. Earlier charts have no pull secret value: mirror
the image to a registry your clusters can already pull from and set `agentImage.repository` to your mirror's repository
name. To turn on agent debug logging, set the chart's `debug` and `debugLevel` values: the controller then starts the
agent with `--debug --debug-level <n>`.

## Non-hardened images vs. Docker Hardened Images

- The runtime image runs as the numeric nonroot user `65532`, whereas the upstream image runs as `1000`. Deployments
  created by the Fleet controller and the upstream charts set `runAsUser: 1000` themselves, and the image starts as
  either user.
- The upstream charts and the controller mount writable `emptyDir` volumes at `/tmp` and `/.kube`. Keep those mounts
  when you enable `readOnlyRootFilesystem`.
- The entrypoint is `/usr/local/bin/fleetagent`, a link to `/usr/bin/fleetagent`. Upstream sets `CMD ["fleetagent"]`
  with no entrypoint. The upstream charts and the controller set `command: [fleetagent]`, which replaces the entrypoint,
  so they work unchanged. With `docker run`, pass flags directly, for example `--version`.
- The image has no shell and no package manager. Use the `dev` variants for debugging.
- Image tags have no `v` prefix; `0.16.3` replaces upstream's `v0.16.3`.

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
