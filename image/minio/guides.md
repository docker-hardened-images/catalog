## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Extended lifecycle support

MinIO no longer publishes community AGPL releases. This image ships an extended lifecycle support (ELS) rebuild of the
last community release, which continues to receive maintenance after upstream stopped. Pulling it requires an ELS
entitlement on your Docker organization; without one, `docker pull` fails with an authorization error even after
`docker login dhi.io`.

### Image tags and the reported MinIO version

The image is tagged from the ELS package version, which encodes the upstream release it derives from as
`0.<YYYYMMDD>.<HHMMSS>` — for example `0.20251015.172955` for `RELEASE.2025-10-15T17-29-55Z`. The timestamp the binary
reports is not that release: it is the datetime the ELS build itself was produced, so `minio --version` prints a later
timestamp than the image tag, and that timestamp advances with every rebuild of the same upstream release:

```
$ docker run --rm dhi.io/minio:<tag> --version
minio version RELEASE.2026-04-29T13-53-29Z (commit-id=0c56c430f7e9ecb422ecafe21227af7c7e2f4b72)
```

Pin the image tag, not the string printed by `minio --version`.

### Start a MinIO instance

To start a MinIO instance, run the following command. Replace `<tag>` with the image variant you want to run.

```
$ docker run -p 9000:9000 dhi.io/minio:<tag>
```

The image sets `MINIO_VOLUMES=/data` and defaults to `minio server`, so the command above serves the `/data` directory
without any further arguments.

To start a MinIO instance with the web UI, publish a second port and pass `--console-address`:

```
$ docker run -p 9000:9000 -p 9001:9001 dhi.io/minio:<tag> server --console-address=":9001"
```

- Port 9000 - API endpoint (health checks work here)
- Port 9001 - Web UI

Then visit http://localhost:9001 in your browser. Login with the default credentials `minioadmin / minioadmin` (or your
custom credentials if set). Use the `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` environment variables to set custom
credentials (minimum 8 characters for password).

## Common MinIO use cases

### Start MinIO with custom credentials

Ensure that no containers are running on the required ports:

```
$ docker run -d --name minio-test -p 9000:9000 -p 9001:9001 \
    -e MINIO_ROOT_USER=myadmin \
    -e MINIO_ROOT_PASSWORD=mypassword123 \
    dhi.io/minio:<tag> \
    server /data --console-address ":9001"

# Test that MinIO is available
$ curl -f http://localhost:9000/minio/health/live

# Access the web UI at http://localhost:9001 with credentials: myadmin / mypassword123

# Cleanup
$ docker stop minio-test && docker rm minio-test
```

### Run MinIO with persistence

Runtime variants run as the nonroot user (UID 65532), which owns `/data` inside the image. A named volume inherits that
ownership on first use, so no extra permission setup is needed:

```
# Create volume
$ docker volume create minio-data

# Start MinIO with persistent volume
$ docker run -d --name minio-persist-test \
    -p 9000:9000 -p 9001:9001 \
    -e MINIO_ROOT_USER=myadmin \
    -e MINIO_ROOT_PASSWORD=mypassword123 \
    -v minio-data:/data \
    dhi.io/minio:<tag> \
    server /data --console-address ":9001"

# Configure the AWS CLI against the running server
$ export AWS_ACCESS_KEY_ID=myadmin
$ export AWS_SECRET_ACCESS_KEY=mypassword123

# Create a bucket and upload a file
$ aws --endpoint-url=http://localhost:9000 s3 mb s3://test-bucket
$ echo "Test persistence data" > test-file.txt
$ aws --endpoint-url=http://localhost:9000 s3 cp test-file.txt s3://test-bucket/
$ aws --endpoint-url=http://localhost:9000 s3 ls s3://test-bucket/

# Recreate the container against the same volume
$ docker stop minio-persist-test && docker rm minio-persist-test
$ docker run -d --name minio-persist-test2 \
    -p 9000:9000 -p 9001:9001 \
    -e MINIO_ROOT_USER=myadmin \
    -e MINIO_ROOT_PASSWORD=mypassword123 \
    -v minio-data:/data \
    dhi.io/minio:<tag> \
    server /data --console-address ":9001"

# The object is still there
$ aws --endpoint-url=http://localhost:9000 s3 ls s3://test-bucket/

# Cleanup
$ docker stop minio-persist-test2 && docker rm minio-persist-test2
$ docker volume rm minio-data
```

If you bind-mount a host directory instead of a named volume, make sure it is writable by UID 65532.

### Ship configuration with a multi-stage Dockerfile

Use a `-dev` variant for stages that need a shell, and a runtime variant for the final stage.

```dockerfile
# syntax=docker/dockerfile:1
FROM dhi.io/minio:<tag>-dev AS setup

WORKDIR /build

COPY config/ ./config/

RUN echo "MinIO version: $(minio --version | head -1)" >> ./config/build-info.txt && \
    ls -lh ./config/

FROM dhi.io/minio:<tag> AS runtime

COPY --from=setup /build/config/ /etc/minio/

EXPOSE 9000 9001

CMD ["server", "/data", "--console-address", ":9001"]
```

Build and run it:

```
$ docker build -t minio-production .

$ docker run -d \
  --name minio-server \
  -p 9000:9000 \
  -p 9001:9001 \
  -v minio-data:/data \
  -e MINIO_ROOT_USER=myadmin \
  -e MINIO_ROOT_PASSWORD=mypassword123 \
  minio-production
```

The runtime variant has no shell or coreutils, so inspect files copied into it with
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) rather than `docker exec`:

```
$ docker debug minio-server -c "cat /etc/minio/build-info.txt"
```

## Non-hardened images vs. Docker Hardened Images

The upstream `minio/minio` image runs as root through a `/usr/bin/docker-entrypoint.sh` wrapper, which optionally
re-executes the server as another account based on `MINIO_USERNAME`, `MINIO_GROUPNAME`, `MINIO_UID`, and `MINIO_GID`.
That wrapper is deprecated upstream and is not the entry point here.

| Item                   | Upstream `minio/minio`                                           | Docker Hardened MinIO                                                            |
| ---------------------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Entry point            | `/usr/bin/docker-entrypoint.sh` wrapping `minio`                 | `minio` directly                                                                 |
| User                   | root, optionally switched by the wrapper                         | Runtime: nonroot (UID 65532); dev: root                                          |
| User switching         | `MINIO_USERNAME` / `MINIO_GROUPNAME` / `MINIO_UID` / `MINIO_GID` | Not honored in runtime variants; run the container with `--user` instead         |
| `docker-entrypoint.sh` | Always present                                                   | Present in `-dev` variants only, for Dockerfiles that still invoke it explicitly |
| Shell                  | `sh`                                                             | Runtime: none; dev: `bash` and `sh`                                              |
| Package manager        | Present                                                          | Runtime: none; dev: `apt-get` (Debian variants) or `apk` (Alpine variants)       |

If you relied on `MINIO_USERNAME` / `MINIO_UID` to change the server's account, pass `--user` to `docker run` (or set
`securityContext.runAsUser` in Kubernetes) instead. Both API and web UI ports are unprivileged, so no additional changes
are needed.

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
