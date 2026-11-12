## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this docker-dind image

This Docker Hardened docker-dind image packages a full Docker Engine so you can run Docker inside a container
(Docker-in-Docker). It includes:

- `dockerd`: The Docker daemon that manages images, containers, networks, and volumes.
- `docker`: The Docker CLI, used to talk to the daemon running in the same container.
- `docker buildx`: The Buildx CLI plugin for building images.
- `containerd` and `runc`: The container runtime and low-level runtime that `dockerd` uses to run containers.
- `dockerd-entrypoint.sh`: The default entry point. It generates TLS certificates (when `DOCKER_TLS_CERTDIR` is set) and
  then starts `dockerd`.

### Run the docker-dind container

The Docker daemon needs elevated privileges to manage nested containers, cgroups, iptables rules, and overlay
filesystems. **You must run this image with `--privileged`.** Without it, `dockerd` fails to start.

```bash
docker run --privileged --rm \
  -v dind-data:/var/lib/docker \
  dhi.io/docker-dind:<tag>
```

To check the daemon and CLI versions built into the image:

```bash
docker run --privileged --rm dhi.io/docker-dind:<tag> dockerd --version
docker run --privileged --rm dhi.io/docker-dind:<tag> docker --version
```

## Common docker-dind use cases

### Run a Docker daemon for CI

Start a dind container with TLS enabled (the default), then connect a client container to it over the network using the
generated certificates:

```bash
docker network create dind-net

docker run --privileged --name dind -d \
  --network dind-net --network-alias docker \
  -e DOCKER_TLS_CERTDIR=/certs \
  -v dind-certs-ca:/certs/ca \
  -v dind-certs-client:/certs/client \
  -v dind-data:/var/lib/docker \
  dhi.io/docker-dind:<tag>

docker run --rm \
  --network dind-net \
  -e DOCKER_TLS_CERTDIR=/certs \
  -e DOCKER_HOST=tcp://docker:2376 \
  -e DOCKER_CERT_PATH=/certs/client \
  -e DOCKER_TLS_VERIFY=1 \
  -v dind-certs-client:/certs/client:ro \
  dhi.io/docker-dind:<tag> docker info
```

This mirrors the standard `docker:dind` usage pattern: the client and the daemon share the `dind-certs-client` volume so
the client can verify the daemon's TLS certificate.

> **Always mount a volume at `/var/lib/docker`.** Unlike upstream `docker:dind`, this hardened image does not declare a
> `VOLUME` (Docker Hardened Images do not ship `VOLUME` metadata). Mount your own volume there
> (`-v dind-data:/var/lib/docker`) so the daemon's storage sits on a real filesystem — without it, the daemon's data
> root lives on the container's own overlay filesystem and starting nested containers fails with an
> `overlay ... invalid argument` mount error.

### Plain-HTTP daemon for local development or testcontainers

For local development, or tools like testcontainers that don't expect TLS, disable certificate generation and expose the
plain HTTP port:

```bash
docker run --privileged --name dind -d \
  -e DOCKER_TLS_CERTDIR="" \
  -p 127.0.0.1:2375:2375 \
  -v dind-data:/var/lib/docker \
  dhi.io/docker-dind:<tag>

DOCKER_HOST=tcp://localhost:2375 docker info
```

This binds the unauthenticated API to the host's loopback interface. If remote clients need access, bind port 2375 to a
specific trusted interface and restrict access with network controls. The daemon accepts unauthenticated connections on
this port when `DOCKER_TLS_CERTDIR` is empty.

### Build an image inside dind

Once a dind container is running, use `docker exec` to build or run images against its nested daemon:

```bash
# Copy the current directory into the running dind container as the build context.
docker exec dind mkdir -p /workspace
docker cp ./. dind:/workspace

docker exec dind docker build -t my-app:latest /workspace
docker exec dind docker buildx build -t my-app:latest /workspace
```

### Advanced configuration

- For custom TLS certificate management (bring-your-own CA, rotating certs), see the upstream
  [`docker:dind` documentation](https://hub.docker.com/_/docker).
- Rootless dind is not provided as a variant of this image. If you need it, use the upstream `docker:dind-rootless`
  image.
- Docker Compose is intentionally not included, unlike the upstream `docker:dind` image. If you need it, install the
  `docker compose` plugin in a derived image or run Compose from a client outside the dind container.
- Daemon-level user-namespace remapping (`--userns-remap`) is not supported: this image omits the `shadow-uidmap`
  tooling and the `dockremap` user / `/etc/subuid` / `/etc/subgid` entries that the feature requires, to keep the
  runtime minimal.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  **`docker-dind` is an exception to the first two points above:** the Docker daemon requires root and `--privileged` to
  manage cgroups, iptables rules, and overlay filesystems, so this image runs as root and includes a busybox shell for
  the entrypoint script. It still has no package manager.

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. In this image, FIPS support covers the OpenSSL provider's crypto path; the Docker Engine
  itself is not FIPS-validated software. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                              |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                 |
| Root user          | This image runs as root because `dockerd` requires root and `--privileged` to manage cgroups, iptables rules, and overlay filesystems.                                                      |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                  |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                          |
| Ports              | The Docker daemon listens on ports 2375 (without TLS) and 2376 (with TLS).                                                                                                                  |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. |
| Shell              | This image includes a busybox shell required by its entrypoint script.                                                                                                                      |

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

Most hardened images intended for runtime don't contain a shell nor any tools for debugging, and the recommended method
is to use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers.
**`docker-dind` is an exception:** it includes a busybox shell and its standard utilities (needed by the entrypoint
script), so you can debug it directly, for example with `docker exec -it <container> sh`. Docker Debug is still
available if you need additional tools beyond what busybox provides.

### Permissions

By default, image variants intended for runtime run as the nonroot user, so you may need to adjust file and directory
permissions for other images. **This doesn't apply to `docker-dind`**: it runs as root (required by `dockerd`), so the
usual nonroot permission adjustments aren't needed here.

### Privileged ports

Non-dev hardened images typically run as a nonroot user by default and so can't bind to privileged ports (below 1024)
without extra configuration. **This doesn't apply to `docker-dind`**: it runs as root, so it can bind to any port. The
daemon listens on `2375`/`2376` by default either way, and both are unprivileged ports.

### Shell

By default, image variants intended for runtime don't contain a shell. **`docker-dind` is an exception**: it includes a
busybox shell (`/bin/sh`), so you can run shell commands directly, for example with `docker exec -it <container> sh`.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
