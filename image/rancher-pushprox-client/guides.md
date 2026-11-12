## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/rancher-pushprox-client:<tag>`
- Mirrored image: `<your-namespace>/dhi-rancher-pushprox-client:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Rancher PushProx Client image

This Docker Hardened Rancher PushProx Client image includes:

- `pushprox-client` at `/usr/bin/pushprox-client`, built from rancher/PushProx.
- The license and third-party notice texts under `/usr/share/licenses/rancher-pushprox-client/`.
- CA certificates (`ca-certificates-bundle`) and time zone data (`tzdata`).

The runtime image does not include `pushprox-proxy`. Run the proxy from its own image, as shown below.

## Start a Rancher PushProx Client image

The image's entrypoint is unset and its default command is `pushprox-client`. Pass the client's flags after the command
name, as with the upstream image.

### Basic usage

Show the client's flags:

```bash
$ docker run --rm dhi.io/rancher-pushprox-client:<tag> pushprox-client --help
```

Without `--proxy-url` the client exits with status 1 and prints `required flag(s) '--proxy-url' not provided`.

### Sidecar with a PushProx proxy

This example runs a PushProx proxy and the client on a user-defined network. The client registers with the proxy under
the name `client` and serves its metrics on port 9369.

```bash
$ docker network create pushprox
$ docker run -d --name pushprox-proxy --network pushprox \
  rancher/pushprox:v0.1.11 pushprox-proxy
$ docker run -d --name client --network pushprox \
  dhi.io/rancher-pushprox-client:<tag> pushprox-client \
  --proxy-url=http://pushprox-proxy:8080 --fqdn=client --allow-port=9369
```

The client is registered when the proxy lists it at `http://pushprox-proxy:8080/clients`. To scrape the client through
the proxy, send the request to the proxy with an absolute URL whose host is the client's `--fqdn`, and set the
`X-Prometheus-Scrape-Timeout-Seconds` header. Without that header the scrape returns `500`:

```bash
$ docker run --rm --network pushprox dhi.io/busybox:1 sh -c \
  'http_proxy=http://pushprox-proxy:8080 wget -qO- --header "X-Prometheus-Scrape-Timeout-Seconds: 5" http://client:9369/metrics'
```

The command uses `dhi.io/busybox:1` because the runtime image has no shell or `wget`.

### Scraping on the local host only

The Rancher chart runs the client with `--use-localhost`. The client then rewrites scrapes to `127.0.0.1`. It must be
given exactly one port to allow with `--allow-port`. Without `--allow-port`, `--use-localhost` exits with status 1 and
prints `client must restrict access on localhost to a single port`.

```bash
$ docker run -d --name client --network pushprox \
  dhi.io/rancher-pushprox-client:<tag> pushprox-client \
  --proxy-url=http://pushprox-proxy:8080 --fqdn=client \
  --use-localhost --allow-port=9369
```

### Bearer token over TLS

Use `--token-path` when the target serves metrics over HTTPS and requires a bearer token. Mount the token file and the
CA certificate that signed the target's certificate, both read-only. Store the token without a trailing newline.

```bash
$ docker run -d --name client --network pushprox \
  -v "$PWD/token:/run/secrets/pushprox/token:ro" \
  -v "$PWD/ca.crt:/etc/pushprox/ca.crt:ro" \
  dhi.io/rancher-pushprox-client:<tag> pushprox-client \
  --proxy-url=http://pushprox-proxy:8080 --fqdn=target.example.internal \
  --token-path=/run/secrets/pushprox/token --tls.cacert=/etc/pushprox/ca.crt
```

The client sends the token only when `--token-path` is set. A target that requires the token refuses the scrape with
`401` otherwise.

### Running as a non-root user

Runtime images run as the numeric user `65532` by default. The client does not write to its root filesystem, so it runs
with a read-only root filesystem:

```bash
$ docker run -d --name client --network pushprox --read-only \
  --user 1000:1000 dhi.io/rancher-pushprox-client:<tag> pushprox-client \
  --proxy-url=http://pushprox-proxy:8080 --fqdn=client --allow-port=9369
```

## Common Rancher PushProx Client use cases

- Scrape targets behind NAT or a firewall through one PushProx proxy, with the client as a sidecar or DaemonSet.
- Run the chart's localhost mode, where the client scrapes only its own allowed port.
- Scrape HTTPS targets that require a bearer token, with the token file and CA mounted read-only.

## Non-hardened images vs. Docker Hardened Images

- The upstream `rancher/pushprox-client` image runs as root. This image runs as `65532`. Set `runAsUser` only if you
  need a different UID, and make sure any mounted files are readable by that UID.
- The upstream image exposes no port. This image declares `9369/tcp`, the client's default metrics listener.
- The runtime image has no shell or busybox. Upstream's Alpine base has them. The client does not need a shell. Use the
  `-dev` variant to inspect files in a container.
- The runtime image does not include `pushprox-proxy`. Upstream's combined `rancher/pushprox` image ships it.

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
