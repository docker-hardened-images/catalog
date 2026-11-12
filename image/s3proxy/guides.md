## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included

This image builds S3Proxy from source and runs it on the Eclipse Temurin JRE. It ships the S3Proxy jar together with the
upstream `run-docker-container.sh` launcher, so the same `S3PROXY_*` and `JCLOUDS_*` environment variables used by the
upstream `andrewgaul/s3proxy` image continue to work. See the [S3Proxy documentation](https://github.com/gaul/s3proxy)
for the full list of configuration options and storage backends.

## Run the container

Run the following command to start S3Proxy with its default filesystem backend:

```bash
$ docker run -d --name s3proxy -p 8080:8080 dhi.io/s3proxy:<tag>
```

S3Proxy listens on port `8080` inside the container and, by default, requires AWS Signature v2 or v4 signed requests
using the identity `local-identity` and credential `local-credential`. An unauthenticated request to `/` returns an S3
`AccessDenied` (HTTP 403) response, which confirms the service is up. Objects are stored on the local filesystem under
`/data`.

### Ports

The upstream `andrewgaul/s3proxy` image listens on privileged port `80` because it runs as `root`. Docker Hardened
Images run as the nonroot user (uid 65532), which cannot bind ports below 1024, so this image defaults
`S3PROXY_ENDPOINT` to `http://0.0.0.0:8080`. Map it to whatever host port you need, for example `-p 80:8080`. To change
the in-container port, override `S3PROXY_ENDPOINT` (keep it at 1024 or higher).

### Configuration

S3Proxy is configured through environment variables that the launcher maps to Java system properties. The most common
ones are:

| Variable                     | Description                                        | Default               |
| ---------------------------- | -------------------------------------------------- | --------------------- |
| `S3PROXY_ENDPOINT`           | Address S3Proxy listens on                         | `http://0.0.0.0:8080` |
| `S3PROXY_AUTHORIZATION`      | Authorization scheme (`aws-v2-or-v4`, `none`, ...) | `aws-v2-or-v4`        |
| `S3PROXY_IDENTITY`           | S3 access key clients must present                 | `local-identity`      |
| `S3PROXY_CREDENTIAL`         | S3 secret key clients must present                 | `local-credential`    |
| `JCLOUDS_PROVIDER`           | jclouds storage backend                            | `filesystem-nio2`     |
| `JCLOUDS_FILESYSTEM_BASEDIR` | Base directory for the filesystem backend          | `/data`               |

For example, to disable authorization and use an anonymous S3 endpoint:

```bash
$ docker run -d --name s3proxy \
  -p 8080:8080 \
  -e S3PROXY_AUTHORIZATION=none \
  dhi.io/s3proxy:<tag>
```

### Persisting data

The filesystem backend stores buckets and objects under `/data`. Mount a volume there to persist data across container
restarts:

```bash
$ docker run -d --name s3proxy \
  -p 8080:8080 \
  -v s3proxy-data:/data \
  dhi.io/s3proxy:<tag>
```

### Proxying to another backend

Point S3Proxy at a different jclouds backend, for example Google Cloud Storage, by overriding the provider and
credentials:

```bash
$ docker run -d --name s3proxy \
  -p 8080:8080 \
  -e JCLOUDS_PROVIDER=google-cloud-storage \
  -e JCLOUDS_IDENTITY=<service-account> \
  -e JCLOUDS_CREDENTIAL=<private-key> \
  dhi.io/s3proxy:<tag>
```

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

This image keeps the upstream `dumb-init` entry point and the `run-docker-container.sh` launcher, so the `S3PROXY_*` and
`JCLOUDS_*` environment variables behave the same as the upstream `andrewgaul/s3proxy` image. The one intentional
difference is the default listen port, which is `8080` instead of the upstream `80` because the image runs as the
nonroot user (see [Ports](#ports)).
