## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/keda-http-add-on-interceptor:<tag>`
- Mirrored image: `<your-namespace>/dhi-keda-http-add-on-interceptor:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The interceptor is the proxy component of the KEDA HTTP Add-on. It watches `InterceptorRoute` resources and the
EndpointSlices of the Services they target through the Kubernetes API, and runs beside the add-on's operator and scaler.
This image replaces `ghcr.io/kedacore/http-add-on-interceptor` on the 0.x line. Add-on concepts and configuration are
documented at https://keda.sh/http-add-on/.

The Debian 13 runtime tag is `dhi.io/keda-http-add-on-interceptor:0`. The Alpine 3.24 runtime tag is
`dhi.io/keda-http-add-on-interceptor:0-alpine3.24`.

## Start a KEDA HTTP Add-on Interceptor image

The entrypoint is `/ko-app/interceptor`, the upstream image's path, and the image sets no command. Runtime tags run as
user 65532 and contain no shell.

### Basic usage

```bash
docker run --rm dhi.io/keda-http-add-on-interceptor:0 --help
```

The interceptor reads its configuration from environment variables, and `KEDA_HTTP_PROXY_PORT` and
`KEDA_HTTP_ADMIN_PORT` are required. Outside a cluster, point the `KUBECONFIG` environment variable at a kubeconfig
file. The admin port serves the `/livez` and `/readyz` probes.

### Install with the upstream Helm chart

The add-on chart creates a KEDA `ScaledObject` for the interceptor, so install KEDA first. Then install the add-on chart
and point its interceptor at this image. The chart applies `images.tag` to all three components and defaults it to the
chart's app version, which is also a tag of this image. Create the `dhi-pull-secret` image pull secret for `dhi.io` in
the `keda` namespace first.

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace
helm install http-add-on kedacore/keda-add-ons-http \
  --namespace keda \
  --set images.interceptor=dhi.io/keda-http-add-on-interceptor \
  --set interceptor.imagePullSecrets[0].name=dhi-pull-secret
```

The chart runs the interceptor with a read-only root filesystem and no capabilities.

### Route traffic to a Service

An `InterceptorRoute` sends requests that match its rules to a Service. This route sends requests for
`myapp.example.com` to port 8080 of the `myapp` Service:

```yaml
apiVersion: http.keda.sh/v1beta1
kind: InterceptorRoute
metadata:
  name: myapp
  namespace: default
spec:
  target:
    service: myapp
    port: 8080
  rules:
    - hosts:
        - myapp.example.com
  scalingMetric:
    concurrency:
      targetValue: 100
```

Traffic reaches the interceptor through the chart's `keda-add-ons-http-interceptor-proxy` Service on port 8080, usually
behind an ingress. To try a route, forward a local port to that Service in one terminal:

```bash
kubectl -n keda port-forward svc/keda-add-ons-http-interceptor-proxy 8080
```

Then send a request with the route's host from another terminal:

```bash
curl -H 'Host: myapp.example.com' http://localhost:8080/
```

A request for a host that no route matches gets a `404`.

### Serve TLS

With `KEDA_HTTP_PROXY_TLS_ENABLED=true`, the interceptor also serves the proxy over TLS on `KEDA_HTTP_PROXY_TLS_PORT`
(default `8443`), with the certificate and key at `/certs/tls.crt` and `/certs/tls.key`. The chart sets these with
`interceptor.tls.enabled=true` and mounts the `interceptor.tls.certSecret` Secret at `/certs`.

A request that arrives over TLS is forwarded to the backend Service over HTTPS. The interceptor verifies the backend's
certificate against the image's CA bundle and the PEM files in the directories `KEDA_HTTP_TLS_CA_DIRS` lists, which the
chart sets from `interceptor.tls.caDirs`.

In FIPS variants, the TLS proxy negotiates only cipher suites that FIPS 140-3 approves. A client that offers only
ChaCha20-Poly1305 fails the TLS handshake.

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
