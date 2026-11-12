## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/apache-polaris-admin-tool:<tag>`
- Mirrored image: `<your-namespace>/dhi-apache-polaris-admin-tool:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start an Apache Polaris Admin Tool image

The image runs the admin tool and passes the container arguments to it. List the commands with `--help`:

```bash
$ docker run --rm dhi.io/apache-polaris-admin-tool:<tag> --help
```

Print the version:

```bash
$ docker run --rm dhi.io/apache-polaris-admin-tool:<tag> --version
```

### Environment variables

The admin tool reads its configuration from environment variables or from `/deployments/config/application.properties`.

| Variable                                            | Description                                                    | Default                                | Required                |
| --------------------------------------------------- | -------------------------------------------------------------- | -------------------------------------- | ----------------------- |
| `POLARIS_PERSISTENCE_TYPE`                          | Persistence backend: `relational-jdbc` or `nosql`              | `relational-jdbc`                      | No                      |
| `QUARKUS_DATASOURCE_JDBC_URL`                       | JDBC URL of the PostgreSQL or CockroachDB database             | None                                   | For `relational-jdbc`   |
| `QUARKUS_DATASOURCE_USERNAME`                       | Database user                                                  | None                                   | For `relational-jdbc`   |
| `QUARKUS_DATASOURCE_PASSWORD`                       | Database password                                              | None                                   | For `relational-jdbc`   |
| `POLARIS_PERSISTENCE_RELATIONAL_JDBC_DATABASE_TYPE` | Set to `cockroachdb` for CockroachDB, as on the Polaris server | `postgresql`, even on CockroachDB      | For CockroachDB         |
| `POLARIS_PERSISTENCE_NOSQL_BACKEND`                 | NoSQL backend: `MongoDb`, or `InMemory` for testing            | None                                   | For `nosql`             |
| `QUARKUS_MONGODB_CONNECTION_STRING`                 | MongoDB connection string                                      | None                                   | For the MongoDB backend |
| `QUARKUS_MONGODB_DATABASE`                          | MongoDB database name                                          | None                                   | For the MongoDB backend |
| `JAVA_TOOL_OPTIONS`                                 | JVM options. A value you set replaces the default              | The `run-java.sh` options listed below | No                      |

## Common Apache Polaris Admin Tool use cases

### Bootstrap a realm in PostgreSQL

Since Apache Polaris 1.8.0, `bootstrap` no longer creates the database schema, so create it first. The following example
starts PostgreSQL on a user-defined network, waits until it accepts connections, creates the schema, and bootstraps the
`polaris` realm with its root credentials:

```bash
$ docker network create polaris
$ docker run -d --name postgres --network polaris \
  -e POSTGRES_PASSWORD=<postgres-password> \
  dhi.io/postgres:18
$ until docker exec postgres pg_isready -q -h 127.0.0.1 -U postgres; do sleep 1; done
$ docker exec postgres psql -U postgres -c 'CREATE SCHEMA polaris_schema'
$ docker run --rm --network polaris \
  -e POLARIS_PERSISTENCE_TYPE=relational-jdbc \
  -e QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://postgres:5432/postgres \
  -e QUARKUS_DATASOURCE_USERNAME=postgres \
  -e QUARKUS_DATASOURCE_PASSWORD=<postgres-password> \
  dhi.io/apache-polaris-admin-tool:<tag> bootstrap -r polaris -c polaris,root,<root-secret>
```

The tool prints `Realm 'polaris' successfully bootstrapped.` and `Bootstrap completed successfully.` Running the command
again skips realms that are already bootstrapped.

### Purge a realm

`purge` deletes a realm and all of its entities:

```bash
$ docker run --rm --network polaris \
  -e POLARIS_PERSISTENCE_TYPE=relational-jdbc \
  -e QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://postgres:5432/postgres \
  -e QUARKUS_DATASOURCE_USERNAME=postgres \
  -e QUARKUS_DATASOURCE_PASSWORD=<postgres-password> \
  dhi.io/apache-polaris-admin-tool:<tag> purge -r polaris
```

### Bootstrap and maintain a MongoDB backend

With the NoSQL persistence backend on MongoDB, bootstrap the realm, then run and inspect persistence maintenance:

```bash
$ docker run --rm \
  -e POLARIS_PERSISTENCE_TYPE=nosql \
  -e POLARIS_PERSISTENCE_NOSQL_BACKEND=MongoDb \
  -e QUARKUS_MONGODB_CONNECTION_STRING=<mongodb-connection-string> \
  -e QUARKUS_MONGODB_DATABASE=polaris \
  dhi.io/apache-polaris-admin-tool:<tag> bootstrap -r polaris -c polaris,root,<root-secret>
$ docker run --rm \
  -e POLARIS_PERSISTENCE_TYPE=nosql \
  -e POLARIS_PERSISTENCE_NOSQL_BACKEND=MongoDb \
  -e QUARKUS_MONGODB_CONNECTION_STRING=<mongodb-connection-string> \
  -e QUARKUS_MONGODB_DATABASE=polaris \
  dhi.io/apache-polaris-admin-tool:<tag> nosql maintenance-run
$ docker run --rm \
  -e POLARIS_PERSISTENCE_TYPE=nosql \
  -e POLARIS_PERSISTENCE_NOSQL_BACKEND=MongoDb \
  -e QUARKUS_MONGODB_CONNECTION_STRING=<mongodb-connection-string> \
  -e QUARKUS_MONGODB_DATABASE=polaris \
  dhi.io/apache-polaris-admin-tool:<tag> nosql maintenance-log
```

The Apache Polaris Helm chart runs `nosql maintenance-run` from this image as an optional CronJob. To use the hardened
image there, set `maintenance.image.repository` in the chart values.

### Use a configuration file

The tool runs in `/deployments` and reads `/deployments/config/application.properties`, the path the Helm chart mounts.
For example, with this `config/application.properties` on the host:

```properties
polaris.persistence.type=relational-jdbc
quarkus.datasource.jdbc.url=jdbc:postgresql://postgres:5432/postgres
quarkus.datasource.username=postgres
```

Mount the directory and pass the password as an environment variable:

```bash
$ docker run --rm --network polaris \
  -v "$(pwd)/config:/deployments/config:ro" \
  -e QUARKUS_DATASOURCE_PASSWORD=<postgres-password> \
  dhi.io/apache-polaris-admin-tool:<tag> bootstrap -r polaris -c polaris,root,<root-secret>
```

## Non-hardened images vs. Docker Hardened Images

- The image starts the tool with `java -jar /deployments/polaris-admin-tool.jar` instead of the `run-java.sh` launcher.
  The launcher's variables, such as `JAVA_OPTS`, `JAVA_OPTS_APPEND`, `JAVA_MAX_MEM_RATIO`, `JAVA_DEBUG` and the
  `http_proxy` translation, have no effect.
- `JAVA_TOOL_OPTIONS` defaults to the JVM options the launcher passes:
  `-XX:MaxRAMPercentage=80.0 -XX:+UseParallelGC -XX:MinHeapFreeRatio=10 -XX:MaxHeapFreeRatio=20 -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -XX:+ExitOnOutOfMemoryError`.
  A value you set replaces them, so repeat the ones you want to keep, for example
  `-e JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=50.0 -XX:+ExitOnOutOfMemoryError"`.
- The working directory is `/deployments`. The upstream image configuration says `/home/polaris`, but its launcher
  changes to `/deployments` before it starts the tool.
- The tool runs as the `polaris` user (UID 10000, GID 10001), like upstream. `/deployments` is read-only for that user
  and has no `data` directory.
- Runtime variants have no shell. AWS profiles that use `credential_process`, which the AWS SDK runs through `sh -c`,
  fail there. Use another source in the AWS default credentials chain, such as environment variables or a web identity
  token.
- The image uses Eclipse Temurin 21 instead of Red Hat OpenJDK 21.
- In FIPS variants, `JDK_JAVA_OPTIONS` loads the BouncyCastle FIPS provider for the tool. `JAVA_TOOL_OPTIONS` starts
  with the FIPS `java.security` settings, so JVM tools that ignore `JDK_JAVA_OPTIONS`, such as `keytool`, have no RSA,
  EC or TLS support instead of falling back to non-FIPS providers. Keep `JDK_JAVA_OPTIONS`, and keep the leading
  `JAVA_TOOL_OPTIONS` settings, which `docker inspect` shows, when you set your own. Options in `JDK_JAVA_OPTIONS` take
  precedence over the same options in `JAVA_TOOL_OPTIONS`.
- In FIPS variants, a PostgreSQL or MongoDB password used for SCRAM authentication must be at least 112 bits, which is
  14 ASCII characters. A shorter password fails with `password must be at least 112 bits`.

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
