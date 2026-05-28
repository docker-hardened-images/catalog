## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About the datahub-frontend-react image

This Docker Hardened DataHub Frontend image packages the web UI layer of the [DataHub](https://datahub.com) open-source
metadata platform. It runs a Play Framework 2.8 (Scala/Java 17) application server that serves the React/Vite/TypeScript
single-page application on port 9002. The image ships the fully staged Play distribution at `/datahub-frontend/`, the
entrypoint script at `/start.sh`, and two Java agent JARs — the OpenTelemetry Java agent and the JMX Prometheus agent —
at `/opt/javaagents/` (symlinked to `/opentelemetry-javaagent.jar` and `/jmx_prometheus_javaagent.jar` in the root for
compatibility with the upstream start script).

DataHub Frontend is one component of the broader DataHub platform. It must be paired with the DataHub GMS (Generalized
Metadata Service) backend and, for a complete deployment, with Kafka, Elasticsearch, and a relational database. The
image is built on the Docker Hardened Eclipse Temurin 17 JRE (Debian 13) and runs as the `nonroot` user (UID 65532) by
default.

### Run the datahub-frontend-react container

The container requires at minimum a unique Play secret key (`DATAHUB_SECRET`) and the address of the GMS backend. The
container will not start without `DATAHUB_SECRET`.

To start a basic instance pointing at a GMS service named `datahub-gms` on port 8080:

```bash
docker run --rm -p 9002:9002 \
  -e DATAHUB_SECRET=change-me-in-production \
  -e DATAHUB_GMS_HOST=datahub-gms \
  -e DATAHUB_GMS_PORT=8080 \
  dhi.io/datahub-frontend-react:<tag>
```

Once the container is running, open `http://localhost:9002` in a browser to access the DataHub web UI.

To verify the process has started, check the readiness endpoint from your host (the runtime image does not ship `curl`
or `wget` itself):

```bash
curl -fsS http://localhost:9002/admin
```

### Deploy DataHub Frontend with Docker Compose

DataHub Frontend is almost always run as part of a multi-service stack. The following Compose file shows the minimal set
of services required to run the web UI alongside GMS. Refer to the
[DataHub quickstart guide](https://docs.datahub.com/docs/quickstart) for the full production-ready Compose stack
(including Kafka, Elasticsearch, MySQL, and the DataHub Actions service).

```yaml
services:
  datahub-frontend-react:
    image: dhi.io/datahub-frontend-react:<tag>
    ports:
      - "9002:9002"
    environment:
      DATAHUB_SECRET: change-me-in-production
      DATAHUB_GMS_HOST: datahub-gms
      DATAHUB_GMS_PORT: "8080"
      DATAHUB_APP_VERSION: v1.0.0
    depends_on:
      - datahub-gms
    restart: on-failure

  datahub-gms:
    image: acryldata/datahub-gms:<tag>
    ports:
      - "8080:8080"
    environment:
      EBEAN_DATASOURCE_USERNAME: datahub
      EBEAN_DATASOURCE_PASSWORD: datahub
      EBEAN_DATASOURCE_HOST: mysql:3306
      EBEAN_DATASOURCE_URL: jdbc:mysql://mysql:3306/datahub?verifyServerCertificate=false&useSSL=true
      EBEAN_DATASOURCE_DRIVER: com.mysql.jdbc.Driver
      KAFKA_BOOTSTRAP_SERVER: broker:29092
      ELASTICSEARCH_HOST: elasticsearch
      ELASTICSEARCH_PORT: "9200"
      DATAHUB_SECRET: change-me-in-production
    depends_on:
      - mysql
      - elasticsearch
      - broker
```

### Environment variables

The following environment variables configure DataHub Frontend's behavior. All variables with a default are optional
unless noted otherwise.

| Variable                       | Description                                                                                        | Default                                      | Required |
| :----------------------------- | :------------------------------------------------------------------------------------------------- | :------------------------------------------- | :------- |
| `DATAHUB_SECRET`               | Play Framework secret key, used to sign session cookies and tokens. Must be unique per deployment. | none                                         | Yes      |
| `DATAHUB_GMS_HOST`             | Hostname of the DataHub GMS backend.                                                               | `datahub-gms`                                | No       |
| `DATAHUB_GMS_PORT`             | Port of the DataHub GMS backend.                                                                   | `8080`                                       | No       |
| `DATAHUB_GMS_USE_SSL`          | Set to `true` to connect to GMS over HTTPS.                                                        | `false`                                      | No       |
| `SERVER_PORT`                  | Port on which the Play server listens.                                                             | `9002`                                       | No       |
| `DATAHUB_APP_VERSION`          | Application version string reported in the UI.                                                     | `v1.0.0`                                     | No       |
| `DATAHUB_PLAY_MEM_BUFFER_SIZE` | Play HTTP body buffer size.                                                                        | `10MB`                                       | No       |
| `KAFKA_BOOTSTRAP_SERVER`       | Kafka bootstrap server address.                                                                    | `broker:29092`                               | No       |
| `DATAHUB_TRACKING_TOPIC`       | Kafka topic for usage event tracking.                                                              | `DataHubUsageEvent_v1`                       | No       |
| `ELASTIC_CLIENT_HOST`          | Elasticsearch host for client-side search autocomplete.                                            | `elasticsearch`                              | No       |
| `ELASTIC_CLIENT_PORT`          | Elasticsearch port.                                                                                | `9200`                                       | No       |
| `ENABLE_PROMETHEUS`            | Set to `true` to enable the JMX Prometheus agent on port 4318.                                     | unset                                        | No       |
| `ENABLE_OTEL`                  | Set to `true` to enable the OpenTelemetry Java agent with OTLP HTTP export.                        | unset                                        | No       |
| `MFE_CONFIG_FILE_PATH`         | Path to the micro-frontend configuration YAML file.                                                | `/datahub-frontend/conf/mfe.config.dev.yaml` | No       |

#### OIDC single sign-on variables

To enable OIDC-based SSO, set the following variables:

| Variable                  | Description                                                             |
| :------------------------ | :---------------------------------------------------------------------- |
| `AUTH_OIDC_ENABLED`       | Set to `true` to enable OIDC authentication.                            |
| `AUTH_OIDC_CLIENT_ID`     | OIDC client ID registered with your identity provider.                  |
| `AUTH_OIDC_CLIENT_SECRET` | OIDC client secret.                                                     |
| `AUTH_OIDC_DISCOVERY_URI` | OIDC discovery endpoint URL (`/.well-known/openid-configuration`).      |
| `AUTH_OIDC_BASE_URL`      | Base URL of this DataHub Frontend instance (used as redirect URI base). |

#### TLS truststore variables

To configure a custom TLS truststore for outbound HTTPS connections (for example, when GMS uses a private CA):

| Variable                  | Description                                |
| :------------------------ | :----------------------------------------- |
| `SSL_TRUSTSTORE_FILE`     | Path to the JKS or PKCS12 truststore file. |
| `SSL_TRUSTSTORE_TYPE`     | Truststore type: `JKS` or `PKCS12`.        |
| `SSL_TRUSTSTORE_PASSWORD` | Password for the truststore.               |

### Enable metrics with Prometheus

Set `ENABLE_PROMETHEUS=true` to activate the JMX Prometheus Java agent. The agent binds to port 4318 and exposes JVM and
application metrics in Prometheus text format.

```bash
docker run --rm -p 9002:9002 -p 4318:4318 \
  -e DATAHUB_SECRET=change-me-in-production \
  -e DATAHUB_GMS_HOST=datahub-gms \
  -e DATAHUB_GMS_PORT=8080 \
  -e ENABLE_PROMETHEUS=true \
  dhi.io/datahub-frontend-react:<tag>
```

Add a Prometheus scrape job to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: datahub-frontend
    static_configs:
      - targets:
          - datahub-frontend-react:4318
```

### Enable distributed tracing with OpenTelemetry

Set `ENABLE_OTEL=true` to activate the OpenTelemetry Java agent. The agent instruments the Play application and exports
traces via OTLP HTTP to the endpoint configured by `OTEL_EXPORTER_OTLP_ENDPOINT` (defaults to `http://localhost:4318`).

```bash
docker run --rm -p 9002:9002 \
  -e DATAHUB_SECRET=change-me-in-production \
  -e DATAHUB_GMS_HOST=datahub-gms \
  -e DATAHUB_GMS_PORT=8080 \
  -e ENABLE_OTEL=true \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://my-otel-collector:4318 \
  dhi.io/datahub-frontend-react:<tag>
```

### Tune JVM memory

The `/start.sh` entrypoint constructs the `JAVA_OPTS` it hands to the Play launcher from `JAVA_MEMORY_OPTS` (heap sizes;
defaults to `-Xms512m -Xmx1024m`) plus a handful of fixed flags. To override heap sizes and add other flags, set
`JAVA_MEMORY_OPTS`:

```bash
docker run --rm -p 9002:9002 \
  -e DATAHUB_SECRET=change-me-in-production \
  -e DATAHUB_GMS_HOST=datahub-gms \
  -e DATAHUB_GMS_PORT=8080 \
  -e JAVA_MEMORY_OPTS="-Xms512m -Xmx1g -XX:+UseG1GC" \
  dhi.io/datahub-frontend-react:<tag>
```

`JAVA_TOOL_OPTIONS` is also honored by the JVM if you need flags applied even earlier in initialization, but
`JAVA_MEMORY_OPTS` is the upstream DataHub knob and matches the variables the upstream Helm chart sets.

### Use the FIPS variant

The `*-fips` and `*-fips-dev` tags use the Docker Hardened Eclipse Temurin 17 FIPS JRE as their runtime base. That JRE
is preconfigured with BouncyCastle FIPS as `security.provider.1` in `java.security`, with the BC JARs at
`/opt/bouncycastle/`. The Play application inherits FIPS-validated cryptography through the standard JSSE/JCE plumbing —
no application-level configuration changes are required.

```bash
docker run --rm -p 9002:9002 \
  -e DATAHUB_SECRET=change-me-in-production \
  -e DATAHUB_GMS_HOST=datahub-gms \
  -e DATAHUB_GMS_PORT=8080 \
  dhi.io/datahub-frontend-react:<tag>-fips
```

The FIPS variant is validated under FIPS 140-3 using BouncyCastle FIPS and the OpenSSL FIPS Provider 3.0. DataHub JWTs
and Play's `play.http.secret.key` signing use FIPS-approved algorithms when the container runs on this JRE.

## Differences from upstream `acryldata/datahub-frontend-react`

| Aspect           | Upstream                                                                 | Docker Hardened Image                                                                                                                   |
| :--------------- | :----------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------- |
| Base image       | `alpine:3.22` with `openjdk17-jre-headless` (apk)                        | Debian 13 (minimal), using Docker Hardened Eclipse Temurin 17 JRE                                                                       |
| Default user     | `datahub` (system-allocated UID)                                         | `nonroot` (UID 65532)                                                                                                                   |
| Entrypoint       | `CMD ./start.sh` with `WORKDIR /`                                        | `ENTRYPOINT ["/start.sh"]` (absolute path, no working-directory dependency)                                                             |
| Shell in runtime | Busybox `/bin/sh` (Alpine; no bash by default)                           | `bash` (required by `/start.sh`)                                                                                                        |
| Package manager  | Yes (`apk`, Alpine base)                                                 | No (package manager not included in the runtime image)                                                                                  |
| FIPS variant     | Not available                                                            | `*-fips` and `*-fips-dev` tags available, using BouncyCastle FIPS + OpenSSL FIPS Provider 3.0                                           |
| Java agent paths | `/opentelemetry-javaagent.jar` and `jmx_prometheus_javaagent.jar` at `/` | Canonical JARs at `/opt/javaagents/`; symlinked to `/opentelemetry-javaagent.jar` and `/jmx_prometheus_javaagent.jar` for compatibility |

### User and volume permissions

The upstream image creates a `datahub` user with a system-allocated UID. The Docker Hardened Image runs as `nonroot`
(UID 65532). If you bind-mount host directories or volumes into the container (for example, a custom MFE config file or
a TLS truststore), ensure the mounted files are readable by UID 65532:

```bash
chown 65532:65532 /path/to/my-mfe-config.yaml
```

Then mount it into the container:

```bash
docker run --rm -p 9002:9002 \
  -e DATAHUB_SECRET=change-me-in-production \
  -e DATAHUB_GMS_HOST=datahub-gms \
  -e DATAHUB_GMS_PORT=8080 \
  -e MFE_CONFIG_FILE_PATH=/datahub-frontend/conf/mfe.config.yaml \
  -v /path/to/my-mfe-config.yaml:/datahub-frontend/conf/mfe.config.yaml:ro \
  dhi.io/datahub-frontend-react:<tag>
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
