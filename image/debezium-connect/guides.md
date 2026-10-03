## How to use this image

Docker Hardened Images are distributed from your organization's private mirror. Authenticate before pulling:

```bash
docker login dhi.io
```

Replace `<tag>` in the examples below with the image tag you want to run.

## Start a Debezium Connect worker

This image runs a single Kafka Connect distributed worker with the Debezium connector plugins installed. It needs a
running Kafka broker to connect to. Point it at your broker with `CONNECT_BOOTSTRAP_SERVERS`, and set the storage topics
Kafka Connect uses to track connector configuration and offsets:

```bash
docker run --rm -p 8083:8083 \
  -e CONNECT_BOOTSTRAP_SERVERS=kafka:9092 \
  -e CONNECT_GROUP_ID=1 \
  -e CONNECT_CONFIG_STORAGE_TOPIC=connect-configs \
  -e CONNECT_OFFSET_STORAGE_TOPIC=connect-offsets \
  dhi.io/debezium-connect:<tag>
```

The worker fails fast at startup if any of these four variables is missing.

## Register a connector

Once the worker is running, register a connector through the Kafka Connect REST API on port 8083:

```bash
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" \
  http://localhost:8083/connectors/ -d '{
    "name": "inventory-connector",
    "config": {
      "connector.class": "io.debezium.connector.mysql.MySqlConnector",
      "database.hostname": "mysql",
      "database.port": "3306",
      "database.user": "debezium",
      "database.password": "dbz",
      "database.server.id": "184054",
      "topic.prefix": "inventory"
    }
  }'
```

See the [Debezium connector documentation](https://debezium.io/documentation/reference/stable/connectors/index.html) for
the configuration options each connector supports.

## Available connectors

This image ships the connector plugins built by the Debezium project's own release: MySQL, MariaDB, PostgreSQL, MongoDB,
SQL Server, Oracle, and the JDBC sink, plus the scripting plugin. It does not include Db2, Spanner, Vitess, Informix, or
IBM i, which the upstream `debezium/connect` image ships as optional downloads. Adding those is tracked as follow-up
work.

Debezium 3.4 removed the separate `debezium-connect-rest-extension` plugin that earlier releases shipped; its
connector-validation, schema, and metrics REST endpoints are now built into `debezium-core` and served by each connector
directly, so no extra plugin is installed or required.

## Oracle connector driver license

The Oracle connector bundles Oracle's JDBC driver (`ojdbc11`), which is distributed under the Oracle Free Use Terms and
Conditions, not Apache-2.0. This is the same driver the upstream Debezium Oracle connector ships. Review the Oracle Free
Use Terms and Conditions if your deployment has a specific license posture to meet.

## Common Kafka Connect environment variables

Any environment variable prefixed `CONNECT_` is translated into the matching `connect-distributed.properties` entry, the
same convention the upstream Debezium and Confluent Kafka Connect images use. For example,
`CONNECT_KEY_CONVERTER=org.apache.kafka.connect.json.JsonConverter` sets `key.converter` in the worker configuration.

## Non-hardened images vs. Docker Hardened Images

This image runs as a fixed non-root user and does not include the optional Jolokia, OpenTelemetry, or Apicurio Registry
integrations that the upstream `debezium/connect` image can enable. It also does not support the ZooKeeper-era
environment variables that older Debezium images accept.

### Migrating from the upstream image

When replacing `debezium/connect:<tag>` with `dhi.io/debezium-connect:<tag>`:

- The Kafka home directory moved from `/kafka` to `/usr/share/kafka`. Update any scripts or volumes that reference the
  upstream path.
- Connector plugins install to `/usr/share/kafka/connect/<connector-name>` rather than `/kafka/connect`; `plugin.path`
  is preset accordingly.
- Environment variable names are unchanged (`CONNECT_BOOTSTRAP_SERVERS`, `CONNECT_GROUP_ID`, and so on).
- If your deployment relies on arbitrary-UID execution (OpenShift), adjust it to run as the image's non-root user (UID
  65532).

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
