## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/typesense:30`
- Mirrored image: `<your-namespace>/dhi-typesense:30`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The examples use tag `30`, the current major. Tag `29` is the previous maintained major.

This image runs the Typesense server. See [typesense.org](https://typesense.org) for product documentation.

## Start the server

The server does not set `TYPESENSE_DATA_DIR` or `TYPESENSE_API_KEY`. Pass both when you start the container. There is no
default API key. The image includes `/data`, so this quick start does not need a volume. The API listens on port 8108.
Replace `your-api-key` with a key you choose.

```bash
$ docker run -d --name typesense -p 8108:8108 \
  -e TYPESENSE_DATA_DIR=/data \
  -e TYPESENSE_API_KEY=your-api-key \
  dhi.io/typesense:30
```

## Check that the server is up

```bash
$ curl http://localhost:8108/health
{"ok":true}
```

For a few seconds after start, while Raft warms up, that URL can return HTTP 503 and `{"ok":false}`. Retry it until the
body is `{"ok":true}`.

## Index and search

Send the same API key in the `X-TYPESENSE-API-KEY` header.

Create a `companies` collection:

```bash
$ curl -X POST http://localhost:8108/collections \
  -H 'X-TYPESENSE-API-KEY: your-api-key' \
  -H 'Content-Type: application/json' \
  --data '{"name":"companies","fields":[{"name":"company_name","type":"string"},{"name":"num_employees","type":"int32"}],"default_sorting_field":"num_employees"}'
```

Index a document:

```bash
$ curl -X POST http://localhost:8108/collections/companies/documents \
  -H 'X-TYPESENSE-API-KEY: your-api-key' \
  -H 'Content-Type: application/json' \
  --data '{"company_name":"Stark Industries","num_employees":5215}'
{"company_name":"Stark Industries","id":"0","num_employees":5215}
```

Search for `stork`. Typesense treats that as a typo for `Stark` and returns the Stark Industries document:

```bash
$ curl -H 'X-TYPESENSE-API-KEY: your-api-key' \
  'http://localhost:8108/collections/companies/documents/search?q=stork&query_by=company_name'
```

The `document` in the first hit is:

```json
{
  "company_name": "Stark Industries",
  "id": "0",
  "num_employees": 5215
}
```

## Persist data

The quick start writes to `/data` inside the container. That directory is removed with the container. To keep data,
bind-mount a host directory on `/data`. The server runs as uid 65532 and does not create a missing data directory, so
the host directory must already exist and be writable by uid 65532. If a container named `typesense` is already running,
remove it before this example.

```bash
$ mkdir -p "$HOME/typesense-data"
$ sudo chown 65532:65532 "$HOME/typesense-data"
$ docker run -d --name typesense -p 8108:8108 \
  -e TYPESENSE_DATA_DIR=/data \
  -e TYPESENSE_API_KEY=your-api-key \
  -v "$HOME/typesense-data:/data" \
  dhi.io/typesense:30
```

## Non-hardened images vs. Docker Hardened Images

The runtime image runs as uid 65532. It does not include a shell. A host directory bind-mounted on `/data` must be
writable by uid 65532.

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
