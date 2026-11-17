## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kai-gpu-fractioning-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-kai-gpu-fractioning-operator:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a kai-gpu-fractioning-operator image

The operator runs inside a Kubernetes cluster and is installed with the upstream Helm chart. Replace `<tag>` with a
runtime tag; dev variants run as root, which the chart's `runAsNonRoot` rejects.

### Install with the upstream Helm chart

The chart takes every component image from `images.<component>.repository` and `images.<component>.tag`. Docker Hardened
Images tags don't carry the `v` prefix that the upstream tags do. The Debian 13 runtime and FIPS variants also publish
`v0.1.8` and `v0.1.8-fips`, the tags the chart resolves by default. For any other variant, set the tag explicitly:

```bash
$ kubectl create namespace gpu-fractioning
$ kubectl -n gpu-fractioning create secret docker-registry dhi-pull-secret \
  --docker-server=dhi.io --docker-username=<username> --docker-password=<token>
$ helm install gpu-fractioning oci://ghcr.io/kai-scheduler/gpu-fractioning \
  --version v0.1.8 --namespace gpu-fractioning \
  --set 'imagePullSecrets[0].name=dhi-pull-secret' \
  --set images.operator.repository=dhi.io/kai-gpu-fractioning-operator \
  --set images.operator.tag=<tag>
```

The chart's CRD upgrader hook Job and the operator Deployment both run this image. The operator then creates the
`fractiond` and `mpsd` DaemonSets on nodes labelled `nvidia.com/gpu.present=true`, from the `images.fractiond`,
`images.mpsd` and `images.metricsd` values.

### Run the operator directly

The operator needs a cluster to talk to, so outside Kubernetes it only prints its usage:

```bash
$ docker run --rm dhi.io/kai-gpu-fractioning-operator:<tag> --help
```

## Common kai-gpu-fractioning-operator use cases

### Run the whole stack from Docker Hardened Images

Point every component at its Docker Hardened Images repository in a values file. The chart passes the pull secret to the
operator only, so the DaemonSets the operator creates pull their images with the secret attached to their service
account. Create that service account with the secret before you install the chart, because Kubernetes adds a service
account's pull secrets to a pod only when the pod is created:

```yaml
imagePullSecrets:
  - name: dhi-pull-secret
daemonServiceAccount:
  create: false
  name: gpu-fractioning-daemon
images:
  operator:
    repository: dhi.io/kai-gpu-fractioning-operator
  fractiond:
    repository: dhi.io/kai-gpu-fractioning-fractiond
  mpsd:
    repository: dhi.io/kai-gpu-fractioning-mpsd
  metricsd:
    repository: dhi.io/kai-gpu-fractioning-metricsd
```

With no tag set, every component resolves the chart's default `v0.1.8`, which the Debian 13 runtime images publish.
`mpsd` and `metricsd` ship on Debian 13 only, so to run the Alpine operator, set `images.operator.tag` alone and leave
the node components on their default tags.

```bash
$ kubectl -n gpu-fractioning create serviceaccount gpu-fractioning-daemon
$ kubectl -n gpu-fractioning patch serviceaccount gpu-fractioning-daemon \
  -p '{"imagePullSecrets":[{"name":"dhi-pull-secret"}]}'
$ helm install gpu-fractioning oci://ghcr.io/kai-scheduler/gpu-fractioning \
  --version v0.1.8 --namespace gpu-fractioning -f values.yaml
```

### Select the FIPS images

With `global.fipsMode=on` the chart appends `-fips` to every resolved image tag, so the default tags resolve to
`v0.1.8-fips`. Keep any `images.<component>.tag` you set without the suffix:

```bash
$ helm install gpu-fractioning oci://ghcr.io/kai-scheduler/gpu-fractioning \
  --version v0.1.8 --namespace gpu-fractioning -f values.yaml --set global.fipsMode=on
```

## Non-hardened images vs. Docker Hardened Images

- Tags have no `v` prefix, so set `images.operator.tag` because the chart's default tag is `v`-prefixed. The Debian 13
  runtime and FIPS variants also publish `v0.1.8` and `v0.1.8-fips`.
- The image runs as the nonroot user `65532`, where the upstream image runs as `1000:1000`. The chart's `runAsNonRoot`
  setting works with both.
- The image is built on Debian 13 or Alpine 3.24 with CA certificates and time zone data. The binary is statically
  linked.

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
