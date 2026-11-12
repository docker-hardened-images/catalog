## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## How to use this image

Apache Druid is a distributed system made up of multiple process types. A production deployment requires external
dependencies - ZooKeeper for cluster coordination and a metadata store (MySQL or PostgreSQL) - in addition to the Druid
processes themselves. Running a single container in isolation is only useful for evaluating the image or running a
single Druid process role.

For a full local deployment, use the official Docker Compose examples from the upstream repository:
https://github.com/apache/druid/tree/master/distribution/docker

### Run a single Druid process

The entrypoint accepts a Druid process role as its argument. Valid roles are `coordinator`, `broker`, `historical`,
`middleManager`, `overlord`, and `router`. Replace `<tag>` with the image tag you want to run.

```console
$ docker run --rm dhi.io/druid:<tag> coordinator
```

### Ports

Each Druid process type listens on a dedicated port:

| Port   | Process       | Description                                          |
| ------ | ------------- | ---------------------------------------------------- |
| `8081` | Coordinator   | Manages data availability and segment assignment     |
| `8082` | Broker        | Routes queries to Historical and MiddleManager nodes |
| `8083` | Historical    | Serves queries against historical segments           |
| `8090` | Overlord      | Manages ingestion task assignment                    |
| `8091` | MiddleManager | Handles ingestion tasks                              |
| `8888` | Router        | Entry point for the Druid web console and API        |

### Persistent data

Druid writes segment data, task logs, and runtime state to `/opt/druid/var` inside the container. Mount a volume at this
path to persist data across container restarts:

```console
$ docker run --rm \
  -v druid-var:/opt/druid/var \
  -p 8888:8888 \
  dhi.io/druid:<tag> router
```

The `DRUID_HOME` environment variable is set to `/opt/druid`. Configuration files are read from
`${DRUID_HOME}/conf/druid`.

### Re-adding removed extensions

Several extensions are excluded from this image to reduce CVE surface area. They can be added back at build time using
`pull-deps` in a multi-stage build from the `-dev` variant:

```dockerfile
FROM dhi.io/druid:36-dev AS extensions

RUN java -cp "/opt/druid/lib/*" org.apache.druid.cli.Main tools pull-deps \
  --no-default-hadoop \
  -c org.apache.druid.extensions:druid-kerberos:36.0.0

FROM dhi.io/druid:36
COPY --from=extensions /opt/druid/extensions /opt/druid/extensions
```

For extensions that require Hadoop, omit `--no-default-hadoop`:

```dockerfile
FROM dhi.io/druid:36-dev AS extensions

RUN java -cp "/opt/druid/lib/*" org.apache.druid.cli.Main tools pull-deps \
  -c org.apache.druid.extensions.contrib:druid-iceberg-extensions:36.0.0

FROM dhi.io/druid:36
COPY --from=extensions /opt/druid/extensions /opt/druid/extensions
```

The removed extensions and their primary use cases are:

| Extension                     | Use case                                                                                              |
| ----------------------------- | ----------------------------------------------------------------------------------------------------- |
| `hdfs-storage`                | HDFS deep storage backend (requires Hadoop - omit `--no-default-hadoop`)                              |
| `druid-kerberos`              | Kerberos authentication for Kerberized Hadoop clusters (requires Hadoop - omit `--no-default-hadoop`) |
| `druid-cassandra-storage`     | Apache Cassandra deep storage backend                                                                 |
| `aliyun-oss-extensions`       | Alibaba Cloud OSS deep storage                                                                        |
| `druid-cloudfiles-extensions` | Rackspace Cloud Files deep storage                                                                    |
| `druid-testing-tools`         | Test infrastructure, not for production use                                                           |

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                               |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                               |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   If you're using a multi-stage build, update the runtime stage to use a non-dev hardened image. This ensures your
   production containers run with minimal attack surface.

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
