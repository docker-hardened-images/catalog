## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/linkerd-metrics-api:<tag>`
- Mirrored image: `<your-namespace>/dhi-linkerd-metrics-api:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a linkerd-metrics-api image

Linkerd starts this image for you. The Linkerd viz Helm chart runs it in the `metrics-api` deployment and passes the
Linkerd namespace, the cluster domain and the Prometheus URL as arguments. The metrics API serves its API on port 8085
and its admin endpoints, `/ping`, `/ready` and `/metrics`, on port 9995.

### Use the image with the Linkerd viz Helm chart

Install the Linkerd control plane as described in the
[Linkerd installation guide](https://linkerd.io/2/getting-started/), then install the viz extension and pass the image
to the chart:

```bash
$ helm repo add linkerd https://helm.linkerd.io/edge
$ helm install linkerd-viz linkerd/linkerd-viz \
  --create-namespace --namespace linkerd-viz \
  --set metricsAPI.image.registry=dhi.io \
  --set metricsAPI.image.name=linkerd-metrics-api \
  --set metricsAPI.image.tag=<tag>
```

Without `metricsAPI.image.tag` the chart uses its own Linkerd release version, for example `edge-26.10.1`, which is also
a tag of this image. Add `--set imagePullSecrets[0].name=<secret>` when the cluster pulls from `dhi.io` with a pull
secret.

### Check the packaged release

The metrics API prints the Linkerd release it belongs to:

```bash
$ docker run --rm dhi.io/linkerd-metrics-api:<tag> -version
edge-26.10.1
```

## Common linkerd-metrics-api use cases

### Use an external Prometheus with basic auth

Point the metrics API at your own Prometheus and give it the credentials in a secret with `user` and `password` keys,
created in the viz namespace before the chart is installed:

```bash
$ kubectl create namespace linkerd-viz
$ kubectl create secret generic prometheus-creds --namespace linkerd-viz \
  --from-literal=user=<user> --from-literal=password=<password>
$ helm install linkerd-viz linkerd/linkerd-viz \
  --namespace linkerd-viz \
  --set metricsAPI.image.registry=dhi.io \
  --set metricsAPI.image.name=linkerd-metrics-api \
  --set metricsAPI.image.tag=<tag> \
  --set prometheus.enabled=false \
  --set prometheusUrl=http://prometheus.example.com:9090 \
  --set prometheusCredsSecret=prometheus-creds
```

The image ships the CA certificate bundle at `/etc/ssl/certs/ca-certificates.crt`, the same path as the upstream image.

### Query traffic metrics of meshed workloads

The `linkerd viz` CLI commands and the Linkerd dashboard read their metrics from the metrics API. Once the viz extension
runs with this image, show the traffic stats of the deployments in a namespace:

```bash
$ linkerd viz stat deploy --namespace <namespace>
```

### Run the metrics API outside a cluster

The metrics API needs a Kubernetes cluster. Outside a cluster it stops with an error:

```bash
$ docker run --rm dhi.io/linkerd-metrics-api:<tag> -prometheus-url=http://prometheus:9090
```

## Non-hardened images vs. Docker Hardened Images

- Tags carry the Linkerd release the image ships in, for example `edge-26.10.1`, and the release number, for example
  `26.10.1`. The upstream image is tagged with the Linkerd release only. The `26` tag moves to each new edge release of
  2026 and the `26.10` tag to each one of October 2026. Upstream edge releases can include breaking changes, so pin
  `edge-26.10.1` or `26.10.1` to stay on one release.
- The image runs as the nonroot user, UID 65532, where the upstream image runs as root unless the pod sets a user. The
  Linkerd viz chart sets `runAsUser` for the metrics API pod, so Linkerd deployments are not affected.
- The image entrypoint is `/usr/local/bin/linkerd2-metrics-api`. The upstream path `/metrics-api` is a symbolic link to
  the binary.
- `-version` prints the Linkerd release, for example `edge-26.10.1`, from the `LINKERD_CONTAINER_VERSION_OVERRIDE`
  environment variable. The upstream image does not set the variable and prints `dev-undefined`.
- The upstream image ships `/linkerd/LICENSE`. This image does not.
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
