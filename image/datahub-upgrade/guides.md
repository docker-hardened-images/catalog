## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this datahub-upgrade image

The DataHub Upgrade image is a run-to-completion batch container that applies schema migrations, rebuilds search and
graph indices, and emits upgrade readiness signals for a running DataHub deployment. It packages the
`datahub-upgrade.jar` Spring Boot application (Java 17), along with a `dockerize` readiness wrapper that waits for
upstream datastores before the JVM starts, a `kubectl` binary for Kubernetes-side operations, and opt-in OpenTelemetry
and JMX Prometheus Java agents.

The entrypoint is `/datahub/datahub-upgrade/scripts/start.sh`, which reads environment variables to determine which
datastores to wait for and which optional agents to activate, then starts the upgrade job. Pass the job name with
`-u <JobName>` to select which upgrade job to run. Full documentation is available at https://docs.datahub.com.

### Run the datahub-upgrade container

The upgrade job requires connectivity to Elasticsearch and at least one primary datastore. The following example runs
the standard `SystemUpdate` job, which is the job executed during routine DataHub version upgrades:

```bash
docker run --rm \
  -e ELASTICSEARCH_HOST=elasticsearch \
  -e ELASTICSEARCH_PORT=9200 \
  -e EBEAN_DATASOURCE_HOST=mysql:3306 \
  -e EBEAN_DATASOURCE_USERNAME=datahub \
  -e EBEAN_DATASOURCE_PASSWORD=datahub \
  -e EBEAN_DATASOURCE_URL="jdbc:mysql://mysql:3306/datahub?verifyServerCertificate=false&useSSL=true&useUnicode=yes&characterEncoding=UTF-8" \
  -e KAFKA_BOOTSTRAP_SERVER=broker:29092 \
  -e SCHEMA_REGISTRY_URL=http://schema-registry:8081 \
  dhi.io/datahub-upgrade:<tag> -u SystemUpdate
```

To rebuild Elasticsearch indices from the primary metadata store (for example, after an index mapping change or cluster
recovery):

```bash
docker run --rm \
  -e ELASTICSEARCH_HOST=elasticsearch \
  -e ELASTICSEARCH_PORT=9200 \
  -e EBEAN_DATASOURCE_HOST=mysql:3306 \
  -e EBEAN_DATASOURCE_USERNAME=datahub \
  -e EBEAN_DATASOURCE_PASSWORD=datahub \
  -e EBEAN_DATASOURCE_URL="jdbc:mysql://mysql:3306/datahub?verifyServerCertificate=false&useSSL=true&useUnicode=yes&characterEncoding=UTF-8" \
  dhi.io/datahub-upgrade:<tag> -u RestoreIndices
```

To display the help for the upgrade tool directly (bypassing the entrypoint script):

```bash
docker run --rm --entrypoint java \
  dhi.io/datahub-upgrade:<tag> \
  -jar /datahub/datahub-upgrade/bin/datahub-upgrade.jar --help
```

### Supported upgrade jobs

Select the job by passing `-u <JobName>` as the command argument:

| Job name                  | Description                                                                                                                                                                                                                      |
| :------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SystemUpdate`            | Applies default configurations, ingests system defaults, and emits a readiness signal on the `DataHubUpgradeHistory_v1` Kafka topic. All other DataHub services wait for this signal. Run this job during every version upgrade. |
| `SystemUpdateBlocking`    | Blocking subset of `SystemUpdate`. Use when an upgrade includes a long-running migration that must fully complete before other services start.                                                                                   |
| `SystemUpdateNonBlocking` | Non-blocking subset of `SystemUpdate`. Use when the migration can run concurrently with other services starting.                                                                                                                 |
| `RestoreIndices`          | Rebuilds Elasticsearch search and graph indices by replaying MCL events from the primary metadata store. Optional arguments: `batchSize`, `batchDelayMs`, `numThreads`, `aspectName`, `urn`, `urnLike`, `urnBasedPagination`.    |
| `RestoreBackup`           | Restores the SQL document store from a backup file. Requires `BACKUP_READER` and `BACKUP_FILE_PATH`.                                                                                                                             |
| `EvaluateTests`           | Runs Metadata Tests in batches. Recommended as a daily Kubernetes CronJob.                                                                                                                                                       |

### Environment variables

The entrypoint script reads the following environment variables before starting the JVM:

| Variable                    | Required      | Description                                                                                                                                                          |
| :-------------------------- | :------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ELASTICSEARCH_HOST`        | Yes           | Elasticsearch hostname.                                                                                                                                              |
| `ELASTICSEARCH_PORT`        | Yes           | Elasticsearch port (typically `9200`).                                                                                                                               |
| `EBEAN_DATASOURCE_HOST`     | Yes (default) | MySQL/Postgres `host:port` (combined; upstream `start.sh` passes it verbatim to `dockerize -wait tcp://`). Set `SKIP_EBEAN_CHECK=true` to bypass if not using Ebean. |
| `EBEAN_DATASOURCE_USERNAME` | Yes (default) | Datasource username.                                                                                                                                                 |
| `EBEAN_DATASOURCE_PASSWORD` | Yes (default) | Datasource password.                                                                                                                                                 |
| `EBEAN_DATASOURCE_URL`      | Yes (default) | Full JDBC connection URL.                                                                                                                                            |
| `ENTITY_SERVICE_IMPL`       | No            | Entity service backend. Defaults to `ebean`; set to `cassandra` to use Cassandra.                                                                                    |
| `CASSANDRA_DATASOURCE_HOST` | No            | Cassandra host. Set with `ENTITY_SERVICE_IMPL=cassandra`.                                                                                                            |
| `GRAPH_SERVICE_IMPL`        | No            | Graph service backend. Defaults to Neo4j; set to `elasticsearch` to skip Neo4j.                                                                                      |
| `NEO4J_HOST`                | No            | Neo4j host. Required when `GRAPH_SERVICE_IMPL` is not `elasticsearch`.                                                                                               |
| `KAFKA_BOOTSTRAP_SERVER`    | No            | Kafka bootstrap server. Required for `SystemUpdate` to emit the readiness signal.                                                                                    |
| `SCHEMA_REGISTRY_URL`       | No            | Kafka Schema Registry URL.                                                                                                                                           |
| `SKIP_EBEAN_CHECK`          | No            | Set to `true` to skip the Ebean datasource readiness check.                                                                                                          |
| `SKIP_CASSANDRA_CHECK`      | No            | Set to `true` to skip the Cassandra readiness check.                                                                                                                 |
| `SKIP_NEO4J_CHECK`          | No            | Set to `true` to skip the Neo4j readiness check.                                                                                                                     |
| `SKIP_ELASTICSEARCH_CHECK`  | No            | Set to `true` to skip the Elasticsearch readiness check.                                                                                                             |
| `ELASTICSEARCH_USERNAME`    | No            | Elasticsearch username (when security is enabled).                                                                                                                   |
| `ELASTICSEARCH_PASSWORD`    | No            | Elasticsearch password (when security is enabled).                                                                                                                   |
| `ELASTICSEARCH_AUTH_HEADER` | No            | Pre-formed `Authorization` header used instead of username/password.                                                                                                 |
| `ELASTICSEARCH_USE_SSL`     | No            | Set to `true` to enable SSL for Elasticsearch connections.                                                                                                           |
| `ENABLE_OTEL`               | No            | Set to `true` to activate the OpenTelemetry Java agent.                                                                                                              |
| `ENABLE_PROMETHEUS`         | No            | Set to `true` to activate the JMX Prometheus agent (binds to port 4318).                                                                                             |
| `JAVA_OPTS`                 | No            | Extra JVM flags appended to the `java -jar` invocation by `start.sh`.                                                                                                |
| `JMX_OPTS`                  | No            | JMX-specific JVM flags appended by `start.sh` (e.g., RMI agent configuration).                                                                                       |
| `JAVA_TOOL_OPTIONS`         | No            | JVM flags picked up automatically by the JVM (independent of `start.sh`).                                                                                            |

### Deploy with Helm (recommended for production)

In production, `datahub-upgrade` is almost always executed through the official DataHub Helm chart as a pre-install and
pre-upgrade hook, not as a standalone `docker run` command. The Helm chart runs `datahub-upgrade` as the
**`datahubSystemUpdate`** job (template
[`charts/datahub/templates/datahub-upgrade/datahub-system-update-job.yml`](https://github.com/acryldata/datahub-helm/blob/master/charts/datahub/templates/datahub-upgrade/datahub-system-update-job.yml)),
which reads its image from `.Values.datahubSystemUpdate.image`. To use the Docker Hardened Image, override that block in
your `values.yaml`:

```yaml
datahubSystemUpdate:
  image:
    repository: dhi.io/datahub-upgrade
    tag: "<tag>"
```

> The upstream chart also has a separate, **legacy** `datahubUpgrade:` block (the `NoCodeDataMigration` job, disabled by
> default with `enabled: false`). Don't override the image there — it would only affect the legacy job and the active
> `SystemUpdate` job would still pull `acryldata/datahub-upgrade`.

Install or upgrade the chart:

```bash
helm repo add datahub https://helm.datahubproject.io/
helm upgrade --install datahub datahub/datahub \
  --namespace datahub \
  --values values.yaml
```

The full Helm chart reference is available at https://artifacthub.io/packages/helm/datahub/datahub.

### Run with Docker Compose

The following Docker Compose snippet shows a minimal setup that runs `SystemUpdate` as a one-shot service alongside
Elasticsearch and MySQL. For a complete DataHub Compose stack, see the upstream repository.

```yaml
services:
  datahub-upgrade:
    image: dhi.io/datahub-upgrade:<tag>
    command: ["-u", "SystemUpdate"]
    depends_on:
      elasticsearch:
        condition: service_healthy
      mysql:
        condition: service_healthy
    environment:
      ELASTICSEARCH_HOST: elasticsearch
      ELASTICSEARCH_PORT: "9200"
      EBEAN_DATASOURCE_HOST: "mysql:3306"
      EBEAN_DATASOURCE_USERNAME: datahub
      EBEAN_DATASOURCE_PASSWORD: datahub
      EBEAN_DATASOURCE_URL: "jdbc:mysql://mysql:3306/datahub?verifyServerCertificate=false&useSSL=true&useUnicode=yes&characterEncoding=UTF-8"
      KAFKA_BOOTSTRAP_SERVER: broker:29092
      SCHEMA_REGISTRY_URL: http://schema-registry:8081
    restart: "no"

  elasticsearch:
    image: elasticsearch:7.11.1
    environment:
      discovery.type: single-node
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 10

  mysql:
    image: mysql:8.2
    environment:
      MYSQL_ROOT_PASSWORD: datahub
      MYSQL_DATABASE: datahub
      MYSQL_USER: datahub
      MYSQL_PASSWORD: datahub
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 10
```

### FIPS variant

The FIPS variant (`dhi.io/datahub-upgrade:<tag>-fips`) enables FIPS 140-validated cryptography for the Java workload:

- The image is built on `dhi/eclipse-temurin:17-debian13-fips`, the FIPS-validated Temurin JRE.
- BouncyCastle FIPS jars (`bc-fips`, `bctls-fips`, `bcutil-fips`, `bcpkix-fips`, `bc-rng-jent`) are bundled under
  `/opt/bouncycastle/` and wired in at JVM bootstrap via
  `JDK_JAVA_OPTIONS=@/datahub/datahub-upgrade/scripts/datahub-fips.properties`. The properties file prepends the
  BouncyCastle jars to the boot classpath (`-Xbootclasspath/a:`), enables `org.bouncycastle.fips.approved_only=true`,
  and sets the JVM trust store to the BCFKS store shipped by the FIPS Temurin
  (`/opt/java/openjdk/17-jre/lib/security/cacerts.bcfks`). The net effect is that all Java TLS and JCE operations —
  JDBC, Kafka client TLS, Elasticsearch HTTPS — go through BouncyCastle FIPS rather than the default SunJCE provider.
- The bundled `dockerize` helper (a thin TCP/HTTP wait wrapper invoked by `start.sh`) performs no cryptographic
  operations, so it is intentionally built with the non-FIPS `dhi/golang` toolchain in the FIPS variant. The FIPS
  boundary is the JVM; there is no Go crypto path to validate.
- The environment variable `DATAHUB_FIPS=true` is set automatically in this variant so operators can branch on it at
  runtime without inspecting image labels.

To run the FIPS variant:

```bash
docker run --rm \
  -e ELASTICSEARCH_HOST=elasticsearch \
  -e ELASTICSEARCH_PORT=9200 \
  -e EBEAN_DATASOURCE_HOST=mysql:3306 \
  -e EBEAN_DATASOURCE_USERNAME=datahub \
  -e EBEAN_DATASOURCE_PASSWORD=datahub \
  -e EBEAN_DATASOURCE_URL="jdbc:mysql://mysql:3306/datahub?verifyServerCertificate=false&useSSL=true&useUnicode=yes&characterEncoding=UTF-8" \
  dhi.io/datahub-upgrade:<tag>-fips -u SystemUpdate
```

No application-level configuration changes are required to switch from the standard runtime variant to the FIPS variant
— the cryptographic substitution is transparent to the upgrade jobs.

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
