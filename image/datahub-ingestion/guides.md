## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About this image

This Docker Hardened DataHub Ingestion image provides the `datahub` metadata ingestion CLI in two upstream variants:

#### Slim variant (default)

The slim variant is a minimal runtime image equivalent to the upstream `acryldata/datahub-ingestion:<version>-slim`
tags. It bundles the most commonly used ingestion connectors:

- Sources: Snowflake, BigQuery, Redshift, MySQL, PostgreSQL, ClickHouse, Glue, dbt, Looker, LookML, Tableau, Power BI,
  Superset
- Object storage: S3, GCS, Azure Blob Storage (slim variants)
- Streaming: Kafka
- Sinks and core: `datahub-rest`, `datahub-kafka`, `datahub-business-glossary`

#### Locked variant (`-locked`)

The locked variant is hardened for airgap and regulated environments. It installs a minimal connector set (`base`,
`datahub-rest`, `datahub-kafka`, `s3-slim`, `gcs-slim`, `abs-slim`) at build time and sets `UV_INDEX_URL` and
`PIP_INDEX_URL` to an unreachable endpoint, so the image cannot reach PyPI at runtime. Use this variant when your
deployment policy prohibits unaudited runtime package installation.

### Run the datahub container

To display the version:

```console
$ docker run --rm dhi.io/datahub-ingestion:<tag> --version
```

To list installed ingestion plugins (sources and sinks):

```console
$ docker run --rm dhi.io/datahub-ingestion:<tag> check plugins
```

To run an ingestion recipe, mount it into the container and pass `ingest -c <path>`:

```console
$ docker run --rm \
  -v /path/to/recipe.yml:/etc/datahub/recipe.yml:ro \
  -e DATAHUB_GMS_URL=https://your-gms.example.com \
  -e DATAHUB_GMS_TOKEN=$DATAHUB_GMS_TOKEN \
  dhi.io/datahub-ingestion:<tag> ingest -c /etc/datahub/recipe.yml
```

The container runs as the `nonroot` user (uid 65532); ensure mounted recipe and credential files are readable by that
user.

### Customizing the slim variant

If you need an ingestion source that is not in the slim variant, install the extra at build time with a multi-stage
build on the `-dev` variant (which includes `uv` and `apt`):

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: install an extra source into a side venv
FROM dhi.io/datahub-ingestion:<tag>-dev AS build
RUN /opt/datahub/bin/uv pip install --python /opt/datahub/bin/python \
    'acryl-datahub[mongodb]'

# Stage 2: runtime image with the extra source
FROM dhi.io/datahub-ingestion:<tag>
COPY --from=build /opt/datahub /opt/datahub
```

For environments that prohibit runtime package installation (locked variant), build a customized image with the extras
baked in at build time instead.

### Recipe files

DataHub ingestion is driven by YAML recipes that describe sources, sinks, and transformers. Mount recipes as read-only
files and pass them to `datahub ingest`:

```console
$ docker run --rm \
  -v "$(pwd)/recipes:/recipes:ro" \
  dhi.io/datahub-ingestion:<tag> ingest -c /recipes/snowflake.yml
```

For the full recipe reference and source-specific configuration options, see the
[upstream metadata ingestion docs](https://docs.datahub.com/docs/metadata-ingestion).

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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants. Note that database sources which
  authenticate over SCRAM-SHA-256 (such as the `postgres` source) fail on the FIPS variants with
  `could not generate nonce`, because libpq cannot generate the SCRAM client nonce under the FIPS OpenSSL provider. For
  SCRAM-authenticated database ingestion, use a non-FIPS variant or configure the database for a FIPS-compatible auth
  method (for example, client certificates).

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
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The upstream `acryldata/datahub-ingestion` image places the `datahub` binary on `PATH` and sets the entrypoint to
`datahub`. The DHI image keeps the same entrypoint and ships `datahub` at `/opt/datahub/bin/datahub` (the image's `PATH`
is `/opt/datahub/bin:/opt/python/bin:…` so `datahub …` resolves the same way), so existing `docker run … ingest -c …`
invocations work without modification. One important runtime difference is that the upstream image runs as the `datahub`
user (uid 1000), while the Docker Hardened Image runs as the nonroot user (uid 65532).

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

If you mount recipe files or credential files, ensure they are readable by uid 65532.

### Locked variant: PyPI access blocked

The locked variant intentionally blocks PyPI by setting `UV_INDEX_URL` and `PIP_INDEX_URL` to an unreachable endpoint.
If you see `Connection refused` or `Name or service not known` errors from `uv` or `pip` at runtime, you are running the
locked variant by design. Either bake the package into a custom image with the dev variant, or switch to the slim
variant.

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
