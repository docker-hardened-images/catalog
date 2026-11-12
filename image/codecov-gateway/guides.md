## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Prerequisites

Codecov Gateway is the HAProxy entry point of a self-hosted Codecov deployment. It routes each request by path to the
Codecov API, the internal API, the frontend and, when enabled, the MinIO object store, so those services must be
reachable from the gateway container before it starts serving. The
[Codecov self-hosted repository](https://github.com/codecov/self-hosted) carries the reference compose file this image
follows, and the [Codecov configuration reference](https://docs.codecov.com/docs/configuration) documents the
deployment.

## Start a Codecov Gateway instance

At container start the gateway waits until the frontend, the API and the internal API accept TCP connections, renders
the HAProxy configuration from its environment and listens on port 8080. The defaults expect the services at
`frontend:8080` and `api:8000` on the container network, the names the upstream compose file uses:

```bash
$ docker network create codecov
$ docker run -d --name codecov-gateway --network codecov -p 127.0.0.1:8080:8080 \
    dhi.io/codecov-gateway:<tag>
```

Replace `<tag>` with the tag of the variant you want to run. The port is bound to the loopback interface above because
the gateway carries no authentication of its own; publish it through your ingress or TLS termination. The container logs
`Codecov preflight started.` and one `... started.` line per service it waited for, then `Starting haproxy`.
`GET http://localhost:8080/gateway_health` answers HTTP 200 with the release and the upstream commit id as its body
(`<version> <commit>`, for example `26.4.1 f848924`) once HAProxy is serving.

The gateway service of the upstream compose file runs with the image reference swapped and its port bound to the
loopback interface, since the gateway itself carries no authentication:

```yaml
services:
  gateway:
    image: dhi.io/codecov-gateway:<tag>
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      - CODECOV_GATEWAY_MINIO_ENABLED=true
    networks:
      - codecov
    depends_on:
      - api
      - frontend
```

### Environment variables

The entrypoint reads these variables when it renders the HAProxy configuration, so a change needs a container restart.
The `*_HOST_HEADER` defaults pass the request's own `Host` header through to the service.

| Variable                             | Description                                                                                     | Default             |
| ------------------------------------ | ----------------------------------------------------------------------------------------------- | ------------------- |
| `CODECOV_API_HOST`                   | Host of the Codecov API.                                                                        | `api`               |
| `CODECOV_API_PORT`                   | Port of the Codecov API.                                                                        | `8000`              |
| `CODECOV_API_SCHEME`                 | `http` or `https` towards the Codecov API.                                                      | `http`              |
| `CODECOV_API_HOST_HEADER`            | `Host` header sent to the Codecov API.                                                          | `%[req.hdr(Host)]`  |
| `CODECOV_API_ADMIN_ENABLED`          | When `true`, requests under `CODECOV_API_ADMIN_PATH` are routed to the API.                     | `false`             |
| `CODECOV_API_ADMIN_PATH`             | Path of the API's admin interface.                                                              | `admin`             |
| `CODECOV_API_ADMIN_DEBUG_ENABLED`    | Logged only: upstream's routing template does not read it, `/__debug__` always reaches the API. | `false`             |
| `CODECOV_IA_HOST`                    | Host of the Codecov internal API.                                                               | `api`               |
| `CODECOV_IA_PORT`                    | Port of the Codecov internal API.                                                               | `8000`              |
| `CODECOV_IA_SCHEME`                  | `http` or `https` towards the internal API.                                                     | `http`              |
| `CODECOV_IA_HOST_HEADER`             | `Host` header sent to the internal API.                                                         | `%[req.hdr(Host)]`  |
| `CODECOV_DEFAULT_HOST`               | Host of the Codecov frontend, the default backend for every unmatched path.                     | `frontend`          |
| `CODECOV_DEFAULT_PORT`               | Port of the Codecov frontend.                                                                   | `8080`              |
| `CODECOV_DEFAULT_SCHEME`             | `http` or `https` towards the frontend.                                                         | `http`              |
| `CODECOV_DEFAULT_HOST_HEADER`        | `Host` header sent to the frontend.                                                             | `%[req.hdr(Host)]`  |
| `CODECOV_MINIO_HOST`                 | Host of the MinIO object store.                                                                 | `minio`             |
| `CODECOV_MINIO_PORT`                 | Port of the MinIO object store.                                                                 | `9000`              |
| `CODECOV_MINIO_SCHEME`               | `http` or `https` towards MinIO.                                                                | `http`              |
| `CODECOV_MINIO_HOST_HEADER`          | `Host` header sent to MinIO.                                                                    | `%[req.hdr(Host)]`  |
| `CODECOV_GATEWAY_HTTP_PORT`          | Port the gateway listens on for HTTP.                                                           | `8080`              |
| `CODECOV_GATEWAY_HTTPS_PORT`         | Port the gateway listens on for HTTPS when TLS is enabled.                                      | `8443`              |
| `CODECOV_GATEWAY_SSL_ENABLED`        | When set to any value, the gateway terminates TLS with the mounted certificate.                 | unset               |
| `CODECOV_GATEWAY_PROXY_MODE_ENABLED` | When set to any value, every request goes to the frontend and only its port is waited on.       | unset               |
| `CODECOV_GATEWAY_MINIO_ENABLED`      | When set to any value, `/minio` and `/archive` are routed to MinIO.                             | unset               |
| `CODECOV_GATEWAY_CHROOT_DISABLED`    | When set to any value, HAProxy runs without `chroot`. See the differences section.              | `true`              |
| `BUILD_VERSION`                      | First word of the `/gateway_health` response.                                                   | the release         |
| `BUILD_ID`                           | Second word of the `/gateway_health` response.                                                  | the upstream commit |

## Common Codecov Gateway use cases

### Point the gateway at services on other hosts

Set the host, port and scheme of each service, and the `Host` header it expects when it is served under a name of its
own:

```bash
$ docker run -d --name codecov-gateway -p 127.0.0.1:8080:8080 \
    -e CODECOV_API_HOST=api.codecov.example -e CODECOV_API_PORT=443 -e CODECOV_API_SCHEME=https \
    -e CODECOV_API_HOST_HEADER=api.codecov.example \
    -e CODECOV_IA_HOST=api.codecov.example -e CODECOV_IA_PORT=443 -e CODECOV_IA_SCHEME=https \
    -e CODECOV_IA_HOST_HEADER=api.codecov.example \
    -e CODECOV_DEFAULT_HOST=app.codecov.example -e CODECOV_DEFAULT_PORT=443 -e CODECOV_DEFAULT_SCHEME=https \
    -e CODECOV_DEFAULT_HOST_HEADER=app.codecov.example \
    dhi.io/codecov-gateway:<tag>
```

With an `https` scheme the gateway connects to the service over TLS without verifying its certificate, as upstream does.
Requests under `/api`, `/graphql`, `/upload`, `/webhooks`, `/login`, `/validate` and the badge paths reach the API,
`/profiling` reaches the internal API and everything else reaches the frontend.

### Terminate TLS

Mount a PEM file holding the certificate chain followed by the private key at `/etc/codecov/ssl/certs/cert.crt` and
enable TLS. HAProxy opens the file as the runtime user (uid 65532), so the file must be readable by that user: mode
`0644`, or owned by uid 65532, or a Kubernetes secret mounted with `defaultMode: 0644`. A root-owned `0600` file fails
at start with `cannot open the file '/etc/codecov/ssl/certs/cert.crt'`. The gateway then listens on 8443 and redirects
plain HTTP requests on 8080 to HTTPS:

```bash
$ docker run -d --name codecov-gateway --network codecov \
    -p 127.0.0.1:8080:8080 -p 127.0.0.1:8443:8443 \
    -v "$PWD/cert.crt:/etc/codecov/ssl/certs/cert.crt:ro" \
    -e CODECOV_GATEWAY_SSL_ENABLED=true \
    dhi.io/codecov-gateway:<tag>
```

The container logs `Codecov gateway ssl enabled` before HAProxy starts, and every request to a service carries
`X-Forwarded-Proto: https`.

### Route everything to one service

Proxy mode sends every request to the frontend service and waits for that service only, which is useful while the API
runs elsewhere or during a first boot:

```bash
$ docker run -d --name codecov-gateway --network codecov -p 127.0.0.1:8080:8080 \
    -e CODECOV_GATEWAY_PROXY_MODE_ENABLED=true \
    dhi.io/codecov-gateway:<tag>
```

### Serve MinIO through the gateway

When Codecov stores archives in a MinIO service on the same network, route `/minio` and `/archive` to it:

```bash
$ docker run -d --name codecov-gateway --network codecov -p 127.0.0.1:8080:8080 \
    -e CODECOV_GATEWAY_MINIO_ENABLED=true \
    dhi.io/codecov-gateway:<tag>
```

The container logs `Codecov gateway minio enabled`. MinIO is expected at `minio:9000` unless the `CODECOV_MINIO_*`
variables say otherwise; its port is not part of the preflight.

### Health checks and the HAProxy statistics page

`/gateway_health` is answered by HAProxy itself with the release and build id; `/frontend_health` and `/api_health` are
routed to the frontend and the API. HAProxy also serves its statistics page on port 8404 and, as upstream does, opens
its unauthenticated admin stats socket on TCP port 9999 on every interface; never publish 9999, and keep both ports
inside the container network. Runtime images carry no `curl`, so probe from the orchestrator and publish the statistics
page on the loopback interface only:

```bash
$ docker run -d --name codecov-gateway --network codecov \
    -p 127.0.0.1:8080:8080 -p 127.0.0.1:8404:8404 \
    dhi.io/codecov-gateway:<tag>
```

```yaml
readinessProbe:
  httpGet:
    path: /gateway_health
    port: 8080
  periodSeconds: 5
```

When a service does not come up, the preflight logs `Still waiting for Codecov Default to start ...` and gives up with
`Timeout waiting for Codecov Default to start` and exit status 1 after about 30 seconds (60 for the API), the same as
upstream. Restart the gateway once the service is reachable.

### Run a command in the image

Passing a command to the image runs it instead of the preflight and HAProxy, the same as the upstream image:

```bash
$ docker run --rm dhi.io/codecov-gateway:<tag> haproxy -v
```

## Non-hardened images vs. Docker Hardened Images

- The gateway is installed from the `dhi/pkg-codecov-gateway` package: the upstream entrypoint as
  `/usr/bin/codecov-gateway`, also reachable at upstream's `/usr/local/bin/entrypoint.sh`, and the HAProxy configuration
  templates under `/etc/codecov-gateway/`. Upstream keeps the templates next to the rendered files in `/etc/haproxy`;
  this image renders into `/etc/haproxy` as upstream does, but the templates are read-only there. The image's entrypoint
  is `/usr/local/bin/codecov-gateway`. `BUILD_ID` is not set in the image environment; the entrypoint reads the upstream
  commit id from the package, so `/gateway_health` answers the same as upstream.
- The TLS certificate at `/etc/codecov/ssl/certs/cert.crt` must be readable by uid 65532; upstream opens it as root
  before HAProxy drops privileges.
- HAProxy comes from the Docker Hardened Images `haproxy` packages, release 3.4; upstream builds on HAProxy 3.3.
- The image runs as uid 65532, named `haproxy` so HAProxy's `user` and `group` directives resolve; upstream starts as
  root and HAProxy drops to the `haproxy` user (uid 1000). `/etc/haproxy` and `/run` are the only paths the runtime user
  owns, for the rendered configuration and the pid file.
- HAProxy runs without `chroot`: the image sets `CODECOV_GATEWAY_CHROOT_DISABLED=true`, upstream's own switch, because a
  process without root privileges cannot chroot. To restore upstream's default, run the container as root and set the
  variable to an empty value (`--user 0 -e CODECOV_GATEWAY_CHROOT_DISABLED=`).
- The preflight tests each service by the exit status of `nc`, not by the `open` word BusyBox prints, so it works with
  the OpenBSD netcat of the Debian variant as well as with BusyBox on Alpine. Its messages, timeouts and exit status are
  upstream's.
- Upstream publishes the channel tags `latest-stable`, `latest-calver` and `rolling` next to the release tag; this image
  publishes release tags only (`26.4.1`, `26.4`, `26` and their distro-suffixed forms), so a compose file that pins
  `latest-calver` moves to a release tag.
- The runtime image ships `bash`, `coreutils`, `netcat-openbsd` and `envsubst` on Debian and BusyBox and `envsubst` on
  Alpine because the upstream entrypoint needs them; it ships no other shell tooling, no `curl` and no package manager.

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
