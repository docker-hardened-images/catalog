## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/openmetadata:<tag>`
- Mirrored image: `<your-namespace>/dhi-openmetadata:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start an OpenMetadata image

The OpenMetadata server needs a metadata database (MySQL or PostgreSQL) and a search backend (Elasticsearch or
OpenSearch). The server listens on port `8585` (API and UI) and `8586` (admin).

OpenMetadata does not run schema migrations automatically. You must run `./bootstrap/openmetadata-ops.sh migrate`
against the database once before the server starts, otherwise the server fails to boot. The following Compose example
runs the migrations in a one-shot `execute-migrate-all` service and starts the server only after that service completes
successfully. PostgreSQL and OpenSearch use health checks so the migration and the server wait until their dependencies
are ready:

```yaml
services:
  postgres:
    image: dhi.io/postgres:<tag>
    environment:
      POSTGRES_USER: openmetadata_user
      POSTGRES_PASSWORD: openmetadata_password
      POSTGRES_DB: openmetadata_db
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "openmetadata_user", "-d", "openmetadata_db"]
      interval: 5s
      timeout: 10s
      retries: 20

  opensearch:
    image: dhi.io/opensearch:<tag>
    environment:
      discovery.type: single-node
      plugins.security.disabled: "true"
      OPENSEARCH_INITIAL_ADMIN_PASSWORD: StrongPassword123!
    healthcheck:
      test: ["CMD", "bash", "-c", "echo > /dev/tcp/localhost/9200"]
      interval: 10s
      timeout: 10s
      retries: 30

  # Run the schema migrations once, then exit. The server waits for this to
  # complete successfully before it starts.
  execute-migrate-all:
    image: dhi.io/openmetadata:<tag>
    command: ["./bootstrap/openmetadata-ops.sh", "migrate"]
    environment: &openmetadata-env
      DB_DRIVER_CLASS: org.postgresql.Driver
      DB_SCHEME: postgresql
      DB_HOST: postgres
      DB_PORT: "5432"
      OM_DATABASE: openmetadata_db
      DB_USER: openmetadata_user
      DB_USER_PASSWORD: openmetadata_password
      SEARCH_TYPE: opensearch
      ELASTICSEARCH_HOST: opensearch
      ELASTICSEARCH_PORT: "9200"
    depends_on:
      postgres:
        condition: service_healthy
      opensearch:
        condition: service_healthy

  openmetadata-server:
    image: dhi.io/openmetadata:<tag>
    environment: *openmetadata-env
    depends_on:
      execute-migrate-all:
        condition: service_completed_successfully
    ports:
      - "8585:8585"
      - "8586:8586"
```

See the [OpenMetadata documentation](https://docs.open-metadata.org/) for the full list of configuration environment
variables and deployment options.

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

> **Note:** Unlike most Docker Hardened runtime images, the OpenMetadata runtime image includes `bash` and `coreutils`.
> The upstream entry point (`/bin/bash /openmetadata-start.sh`) and the `bootstrap/openmetadata-ops.sh` migration script
> require a shell and these utilities, so they are present in the runtime image. It still omits a package manager and
> other debugging tools.

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
| No shell           | This OpenMetadata runtime image includes `bash` because the entry point requires it. Most hardened runtime images don't contain a shell; for those, use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                       |

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

This OpenMetadata runtime image includes `bash`, but like other hardened runtime images it doesn't include a broad set
of debugging tools. The recommended method for debugging applications built with Docker Hardened Images is to use
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

### Shell

Unlike most Docker Hardened runtime images, this OpenMetadata runtime image includes `bash` (and `coreutils`) because
the entry point (`/bin/bash /openmetadata-start.sh`) and the `bootstrap/openmetadata-ops.sh` scripts require them. For
hardened images that don't contain a shell, use `dev` images in build stages to run shell commands and then copy any
necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
