## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this mlflow image

This Docker Hardened mlflow image includes:

- mlflow CLI and server binaries (mlflow command)
- A minimal Python runtime configured to run mlflow
- Hardened runtime configuration (nonroot runtime, reduced attack surface)

## Start a mlflow image

Below are common ways to run the mlflow server from the hardened image. The mlflow server exposes the tracking UI and
API (default port 5000). In examples below, replace `<tag>` with the image tag.

### Basic usage

```bash
$ docker run -d --name mlflow-server -p 5000:5000 \
  -e MLFLOW_SERVER_HOST=0.0.0.0 \
  -e MLFLOW_SERVER_PORT=5000 \
  dhi.io/mlflow:<tag> server --backend-store-uri sqlite:///mlflow.db --default-artifact-root ./mlruns --host 0.0.0.0 --port 5000
```

This starts a simple single-node tracking server with a local SQLite backend and local artifact folder (suitable for
development and evaluation only).

### With Docker Compose (recommended for production-like setups)

```yaml
version: '3.8'
services:
  postgres:
    image: dhi.io/postgres:<tag>
    environment:
      POSTGRES_USER: mlflow
      POSTGRES_PASSWORD: mlflow
      POSTGRES_DB: mlflowdb
    volumes:
      - mlflow-db:/var/lib/postgresql/data

  minio:
    image: dhi.io/minio:<tag>
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    command: server /data
    ports:
      - "9000:9000"
    volumes:
      - mlflow-minio:/data

  mlflow:
    image: dhi.io/mlflow:<tag>
    container_name: mlflow-server
    ports:
      - "5000:5000"
    environment:
      - MLFLOW_SERVER_HOST=0.0.0.0
      - MLFLOW_SERVER_PORT=5000
      - BACKEND_STORE_URI=postgresql+psycopg2://mlflow:mlflow@postgres:5432/mlflowdb
      - ARTIFACT_ROOT=s3://mlflow-artifacts
      - AWS_ACCESS_KEY_ID=minioadmin
      - AWS_SECRET_ACCESS_KEY=minioadmin
      - MLFLOW_S3_ENDPOINT_URL=http://minio:9000
    command: mlflow server --backend-store-uri ${BACKEND_STORE_URI} --default-artifact-root ${ARTIFACT_ROOT} --host 0.0.0.0 --port ${MLFLOW_SERVER_PORT}
    depends_on:
      - postgres
      - minio

volumes:
  mlflow-db:
  mlflow-minio:

```

### Environment variables

Key environment variables commonly used to configure mlflow server and clients:

| Variable                   | Description                                                                                                                                    | Default                              | Required                             |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------ |
| `MLFLOW_SERVER_HOST`       | Host interface mlflow server listens on inside the container                                                                                   | `127.0.0.1` (overridden in examples) | No                                   |
| `MLFLOW_SERVER_PORT`       | Port for the mlflow server inside the container                                                                                                | `5000`                               | No                                   |
| `BACKEND_STORE_URI`        | SQLAlchemy-compatible URI for the backend store (metadata DB). Examples: `sqlite:///mlflow.db`, `postgresql+psycopg2://user:pass@host:5432/db` | `sqlite:///mlflow.db`                | Yes for production                   |
| `ARTIFACT_ROOT`            | Location where artifacts are stored. Can be a local path (file://), S3 (s3://bucket), GCS, or other supported stores                           | `./mlruns`                           | Yes for production                   |
| `MLFLOW_S3_ENDPOINT_URL`   | Custom S3-compatible endpoint (e.g., MinIO)                                                                                                    | -                                    | No (when using S3-compatible stores) |
| `AWS_ACCESS_KEY_ID`        | Access key for S3-compatible artifact stores                                                                                                   | -                                    | No (when using S3-compatible stores) |
| `AWS_SECRET_ACCESS_KEY`    | Secret key for S3-compatible artifact stores                                                                                                   | -                                    | No (when using S3-compatible stores) |
| `MLFLOW_TRACKING_USERNAME` | Optional basic auth username if reverse proxy or auth middleware is used                                                                       | -                                    | No                                   |
| `MLFLOW_TRACKING_PASSWORD` | Optional basic auth password if reverse proxy or auth middleware is used                                                                       | -                                    | No                                   |

Example run with environment variables:

```bash
$ docker run -d --name mlflow-server -p 5000:5000 \
  -e BACKEND_STORE_URI=postgresql+psycopg2://mlflow:mlflow@postgres:5432/mlflowdb \
  -e ARTIFACT_ROOT=s3://mlflow-artifacts \
  -e AWS_ACCESS_KEY_ID=minioadmin \
  -e AWS_SECRET_ACCESS_KEY=minioadmin \
  -e MLFLOW_S3_ENDPOINT_URL=http://minio:9000 \
  dhi.io/mlflow:<tag> \
  mlflow server --backend-store-uri ${BACKEND_STORE_URI} --default-artifact-root ${ARTIFACT_ROOT} --host 0.0.0.0 --port 5000
```

## Common mlflow use cases

- Basic single-node tracking server (development): SQLite backend and local artifact root. Not suitable for production.

- Production tracking server: Postgres (or other SQL DB) as backend store and S3/MinIO as artifact store. Run behind a
  reverse proxy (nginx) for TLS and authentication.

- Model packaging and serving: Use `mlflow models build-docker` or `mlflow models serve` to containerize and serve
  models. These commands are available in the image's mlflow CLI.

### Example: Packaging and serving a model

1. Package a model saved in `models/` as a Docker image:

```bash
$ docker run --rm -v $(pwd):/app dhi.io/mlflow:<tag> mlflow models build-docker -m /app/models/1 -n mymodel:latest
```

2. Serve the built model image:

```bash
$ docker run -d --name mymodel -p 8080:8080 mymodel:latest
```

## Non-hardened images vs. Docker Hardened Images

For mlflow there are no functional differences in CLI commands. The hardened mlflow image focuses on security (minimal
runtime, nonroot user, reduced packages). Use the hardened image in production environments for improved supply chain
security.

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
| Non-root user      | By default non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                    |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. To ensure that your final image is as minimal as possible, you should use a multi-stage build. While intermediary stages will typically use images tagged as `dev`, your final runtime stage should use a non-dev image variant.            |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell commands and then copy any necessary artifacts to the runtime stage.                                                                                                                                    |

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

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Debug (https://docs.docker.com/reference/cli/docker/debug/) to attach to these
containers. Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral,
writable layer that only exists during the debugging session.

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
