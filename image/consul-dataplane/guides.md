## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/consul-dataplane:<tag>`
- Mirrored image: `<your-namespace>/dhi-consul-dataplane:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Consul Dataplane image

This image contains `consul-dataplane`, the Envoy proxy it starts, and `discover`. They are reachable at the upstream
paths in `/usr/local/bin`: `consul-dataplane`, `envoy` and `discover` link to the packaged binaries in `/usr/bin`, and
`privileged-consul-dataplane` and `privileged-envoy` are copies that carry the `CAP_NET_BIND_SERVICE` file capability,
so they can bind ports below 1024 when that capability is in the container's bounding set. As upstream, the entrypoint
is `/usr/local/bin/dumb-init /usr/local/bin/consul-dataplane`, and the runtime images run as UID 100.

Each tag line follows one consul-dataplane release line and ships the Envoy release line that upstream pairs with it:

| Tag   | consul-dataplane | Envoy  | consul-k8s Helm chart |
| :---- | :--------------- | :----- | :-------------------- |
| `2.1` | 2.1.x            | 1.39.x | 2.1.x                 |
| `1.8` | 1.8.x            | 1.38.x | 1.8.x                 |

The Envoy patch release can differ from the one upstream's image pins for the same consul-dataplane release. The image
installs the newest Envoy patch release of the line that Docker Hardened Images publishes, so it can be newer than
upstream's, for example Envoy 1.39.6 where upstream's `hashicorp/consul-dataplane:2.1.0` ships Envoy 1.39.1. To check
the Envoy version of an image:

```bash
$ docker run --rm --entrypoint envoy dhi.io/consul-dataplane:<tag> --version
```

In sidecar and gateway modes, `consul-dataplane` starts the `envoy` it finds on `PATH`, or the binary that
`-envoy-executable-path` names. This image provides both, so no flag is needed unless you use the privileged copies.

### Quick start: run a sidecar proxy

This example starts a Consul server in development mode (use the Consul version the matching chart line defaults to:
`2.1.0` for `2.1`, `1.21.5` for `1.8`), registers a sidecar proxy service for a `web` service, and runs this image as
that proxy. `consul-dataplane` fetches the proxy's configuration from Consul over gRPC and starts Envoy.

```bash
$ docker network create consul-demo
$ docker run -d --name consul --network consul-demo -p 127.0.0.1:8500:8500 \
  hashicorp/consul:<consul-version> agent -dev -client=0.0.0.0
$ curl -sf -X PUT http://127.0.0.1:8500/v1/catalog/register -d '{"Node":"demo-node","Address":"127.0.0.1",
  "Service":{"ID":"web-sidecar-proxy","Service":"web-sidecar-proxy","Kind":"connect-proxy","Port":20000,
  "Proxy":{"DestinationServiceName":"web","LocalServicePort":8080}}}'
true
$ docker run -d --name web-sidecar --network consul-demo dhi.io/consul-dataplane:<tag> \
  -addresses=consul -grpc-port=8502 -tls-disabled \
  -proxy-service-id=web-sidecar-proxy -service-node-name=demo-node
```

Check that Envoy is up, with the command the Consul webhook uses as the sidecar's startup probe. It can take a few
seconds for Envoy to become ready:

```bash
$ docker exec web-sidecar /usr/local/bin/consul-dataplane -check-proxy-health
Checking envoy proxy health
Envoy proxy is ready.
```

Clean up:

```bash
$ docker rm -f web-sidecar consul
$ docker network rm consul-demo
```

### Use the image with the Consul Helm chart

Point the official `hashicorp/consul` chart at this image with `global.imageConsulDataplane`. Use the chart version that
matches the consul-dataplane version of the image, for example chart `2.1.0` with a `2.1` image:

```bash
$ helm repo add hashicorp https://helm.releases.hashicorp.com
$ helm install consul hashicorp/consul \
  --version <chart-version> \
  --create-namespace --namespace consul \
  --set connectInject.enabled=true \
  --set global.tls.enabled=true \
  --set global.acls.manageSystemACLs=true \
  --set dns.proxy.enabled=true \
  --set global.imageConsulDataplane=dhi.io/consul-dataplane:<tag> \
  --set 'global.imagePullSecrets[0].name=<secret>'
```

The connect-inject webhook adds this image as the `consul-dataplane` sidecar of every mesh pod, keeping the image
entrypoint and passing its flags as arguments. `global.imagePullSecrets` covers only the chart's own pods: give each
mesh application the `dhi.io` pull secret in its own namespace, through the pod's `imagePullSecrets` or its service
account, so that the kubelet can pull the injected sidecar. The chart also runs this image for the mesh, ingress and
terminating gateways and the DNS proxy; when one of them listens on a port below 1024, such as the DNS proxy's default
port 53, the chart runs `privileged-consul-dataplane` with `-envoy-executable-path=/usr/local/bin/privileged-envoy`.

Keep the security context the webhook sets. The sidecar runs as UID 5995 with a read-only root filesystem, and
`consul-dataplane` writes the Envoy bootstrap to the directory `TMPDIR` names, which the webhook points at a writable
volume. To run the image with a read-only root filesystem yourself, mount a writable directory and set `TMPDIR` to it,
for example `--read-only --tmpfs /consul/connect-inject -e TMPDIR=/consul/connect-inject`.

With external Consul servers, the chart's `externalServers.hosts` can name an `exec=` command instead of addresses,
which `consul-dataplane` runs to find the servers. The image ships `discover` for this, for example
`exec=discover -q addrs provider=aws region=us-east-1 tag_key=consul-role tag_value=server`. `discover` prints the
server addresses, one line with spaces between them, and authenticates with the provider's usual credentials.

## FIPS variants

FIPS images use `-fips` tags in this repository, for example `2.1-fips`. To use one with the Helm chart, set
`global.imageConsulDataplane` to a `-fips` tag.

In the FIPS variants, `consul-dataplane` and `discover` are built with the Go Cryptographic Module and run in FIPS 140-3
mode by default, Envoy is built with BoringSSL in FIPS mode, and the OpenSSL FIPS provider is installed and configured.
`consul-dataplane -version` prints a `+fips1403` suffix, and `envoy --version` reports `BoringSSL-FIPS`:

```bash
$ docker run --rm dhi.io/consul-dataplane:<tag>-fips -version
Consul Dataplane v<version>+fips1403
Revision <revision>
```

## Non-hardened images vs. Docker Hardened Images

- **User:** runtime images run as UID 100, as upstream, which the Consul chart's `runAsUser: 100` and the gateways'
  `runAsNonRoot` rely on. Unlike upstream, UID 100 has an `/etc/passwd` entry (user `100`, group `consul-dataplane`, GID
  1000, home `/home/100`); upstream's UID 100 has no entry and runs with GID 0. Dev images run as root.
- **Binary paths:** `consul-dataplane`, `envoy`, `discover` and `dumb-init` in `/usr/local/bin` are symbolic links to
  the packaged binaries in `/usr/bin`. `privileged-consul-dataplane` and `privileged-envoy` are regular files in
  `/usr/local/bin`, as upstream.
- **Envoy:** Envoy is the Docker Hardened Images build of the same release line, at the newest published patch release,
  which can be newer than upstream's. See [Start a Consul Dataplane image](#start-a-consul-dataplane-image).
- **Environment:** the image does not set upstream's `BIN_NAME`, `PRODUCT_NAME` and `SSL_CERT_FILE` variables, which
  nothing in the image reads; the CA bundle is at the same path, `/etc/ssl/certs/ca-certificates.crt`. The FIPS images
  set `SSL_CERT_FILE` to that path.
- **License notices:** license files are in `/usr/share/licenses/consul-dataplane/`, including the notices of bundled Go
  modules, instead of upstream's `/usr/share/doc/consul-dataplane/LICENSE.txt` and `/licenses/copyright.txt`.
- **FIPS:** upstream publishes FIPS images in a separate `hashicorp/consul-dataplane-fips` repository with `-fips1403`
  tags. Here they are `-fips` tags in the same repository.
- **Distribution:** only Debian-based images are available, because Envoy is not built for Alpine's musl C library.

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
