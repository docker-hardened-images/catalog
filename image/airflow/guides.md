## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Airflow image

This Docker Hardened Airflow image provides Apache Airflow in three variants:

#### Core (default) variant

The core variant is a minimal runtime image equivalent to the upstream Apache Airflow "slim" tags. It includes:

- Apache Airflow core components
- Essential Python runtime dependencies
- No provider packages (postgres, celery, etc.)
- No package management tools

Due to the lack of provider packages, the core variant has limited functionality on its own and is primarily intended as
a base for customized Airflow installations.

#### Dev variant (`-dev`)

The dev variant is a build-time image that includes everything in the core variant plus:

- Package management tools
- Build dependencies and tools
- Source code used to build the core image
- Shell access for development and customization

#### Compat (`-compat`) variant

The compat variant is a batteries-included runtime image equivalent to the default upstream Apache Airflow images. It
includes:

- Apache Airflow core components
- Essential Python runtime dependencies
- No package management tools
- The following Airflow provider packages:
  - `amazon`
  - `celery`
  - `cncf-kubernetes`
  - `common-messaging`
  - `docker`
  - `elasticsearch`
  - `fab`
  - `ftp`
  - `git`
  - `google`
  - `grpc`
  - `hashicorp`
  - `http`
  - `microsoft-azure`
  - `mysql`
  - `odbc`
  - `openlineage`
  - `postgres`
  - `redis`
  - `sendgrid`
  - `sftp`
  - `slack`
  - `snowflake`
  - `ssh`

### Start an Airflow container

The following command will run the api-server using the core variant and expose the web interface on port 8080.

```
docker run -it --rm -p 8080:8080 -e AIRFLOW__API_AUTH__JWT_SECRET=test dhi.io/airflow:<tag> api-server
```

> [!NOTE]
>
> The above command is for testing purposes only. It will generate and print the admin username and password for logging
> into the web interface.

### Installing Airflow providers onto the core image

Since the core image doesn't include provider packages, you'll need to use the dev variant to install them and then copy
the installed providers to a core image for runtime use.

**Basic provider installation workflow**

The recommended approach is to use a multi-stage Dockerfile that:

1. Uses the dev variant to install providers
1. Copies the installed providers to the core variant for runtime

Here's a complete example that installs common providers:

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: Install providers using dev variant
FROM dhi.io/airflow:<tag>-dev AS provider-build
WORKDIR /opt/airflow
# Install providers using pip
RUN pip install \
    --constraint constraints.txt \
    --prefix /opt/airflow-providers \
    apache-airflow-providers-postgres \
    apache-airflow-providers-celery \
    apache-airflow-providers-docker \
    apache-airflow-providers-kubernetes

# Stage 2: Runtime image with providers
FROM dhi.io/airflow:<tag> AS runtime
# Copy installed providers from build stage
COPY --from=provider-build /opt/airflow-providers /opt/airflow
# Copy your DAGs and configuration
COPY dags/ /opt/airflow/dags/
COPY airflow.cfg /opt/airflow/airflow.cfg
```

**Providers requiring system dependencies**

Some Airflow providers require system-level dependencies (installed via `apt`). For these cases, you'll need to:

1. Use a multi-stage build or a DHI customization (subscription required) to install the required system dependencies
1. Use the dev variant to install the provider packages
1. Copy the providers to your customized core image

Example workflow for a provider that needs system dependencies:

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: Install providers using dev variant
FROM dhi.io/airflow:<tag>-dev AS provider-build
WORKDIR /opt/airflow
# Install provider that requires system dependencies
RUN pip install \
    --constraint constraints.txt \
    --prefix /opt/airflow-providers \
    apache-airflow-providers-oracle

# Stage 2: Use your customized DHI image with system dependencies
FROM dhi.io/airflow-custom:<tag> AS runtime
# Copy installed providers from build stage
COPY --from=provider-build /opt/airflow-providers /opt/airflow
# Copy your application files
COPY dags/ /opt/airflow/dags/
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- Compat variants support more seamless usage of DHI as a drop-in replacement for upstream images, particularly for
  circumstances that the ultra-minimal runtime variant may not fully support. These images typically:

  - Run as the nonroot user
  - Improve compatibility with upstream helm charts
  - Include optional tools that are critical for certain use-cases

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                            |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the **Tags** tab for this repository. To view what packages are already installed in an image variant, select
   the **Tags** tab for this repository, and then select a tag.

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

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

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

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
