## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About Data Prepper

This Docker Hardened Data Prepper image is a server-side data collector built for trace, log, and metric observability
pipelines. Data Prepper receives telemetry from sources such as OpenTelemetry Collector, Fluent Bit, and S3, applies
processors (field mapping, aggregate, grok, drop events), and routes data to sinks such as OpenSearch, S3, and Kafka.
The image ships the Java 17 JRE (Eclipse Temurin), the full Data Prepper plugin set (83 plugin directories, 582 bundled
JARs), and GNU `gettext-base` for `envsubst`-based pipeline config templating. A writable log directory is provided at
`/var/log/data-prepper`. The default server configuration is at
`/usr/share/data-prepper/config/data-prepper-config.yaml` and pipeline definitions are read from
`/usr/share/data-prepper/pipelines/pipelines.yaml`.

> **Security notice**: The bundled `data-prepper-config.yaml` enables SSL with a self-signed `keystore.p12` and HTTP
> basic authentication using the username `admin` and password `admin`. These defaults are intended for initial
> evaluation only. Replace the keystore and credentials before deploying to any non-development environment.

### Run the Data Prepper container

Data Prepper is configured through two YAML files: a server configuration file and a pipeline definitions file. The
entrypoint is the wrapper script `/usr/share/data-prepper/bin/data-prepper`. When started with no arguments, the wrapper
reads the server config from the default location and expects pipeline definitions to be present.

Start a container using the built-in defaults (self-signed SSL, basic auth `admin`/`admin`, no active pipeline inputs):

```bash
docker run -d --name data-prepper \
  -p 4900:4900 \
  dhi.io/data-prepper:<tag>
```

Verify the server is up by listing the running pipelines (the default config enables SSL, so pass `-k` to skip
certificate validation for the self-signed cert):

```bash
curl -k -u admin:admin https://localhost:4900/list
```

The server responds with the running pipelines, for example `{"pipelines":[{"name":"sample-pipeline"}]}`, once it is
ready. (`/metrics/prometheus` returns the Prometheus metrics; there is no `/health` endpoint.)

> **Note**: The Data Prepper wrapper script accepts either zero or two positional arguments (pipeline config path and
> server config path, in that order). Passing a single argument such as `--version` causes the wrapper to exit with an
> error. To inspect the bundled configuration files, use the `dev` variant or
> [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/).

### Mount custom configuration files

For any real workload, mount your own pipeline and server configuration files into the container.

Create a server configuration file `data-prepper-config.yaml`:

```yaml
ssl: true
keyStoreFilePath: "/path/to/your/keystore.p12"
keyStorePassword: "your-keystore-password"
privateKeyPassword: "your-key-password"
serverPort: 4900
metricRegistries: [Prometheus]
authentication:
  http_basic:
    username: your-admin-user
    password: your-strong-password
```

Create a pipeline definition file `pipelines.yaml` (example: OTel trace pipeline to OpenSearch):

```yaml
otel-trace-pipeline:
  source:
    otel_trace_source:
      port: 2021
      ssl: false
  processor:
    - trace_peer_forwarder:
  sink:
    - opensearch:
        hosts:
          - https://opensearch:9200
        username: admin
        password: your-strong-password
        insecure: false
        index_type: trace-analytics-raw
```

Run Data Prepper with both files mounted:

```bash
docker run -d --name data-prepper \
  -p 4900:4900 \
  -p 2021:2021 \
  -v $(pwd)/pipelines.yaml:/usr/share/data-prepper/pipelines/pipelines.yaml:ro \
  -v $(pwd)/data-prepper-config.yaml:/usr/share/data-prepper/config/data-prepper-config.yaml:ro \
  dhi.io/data-prepper:<tag>
```

### Templated pipeline configuration with envsubst

The image ships `envsubst` (from `gettext-base`) for rendering `${VAR}` placeholders in pipeline configuration files.
This is the recommended pattern for injecting environment-specific values (hostnames, passwords, index prefixes) into
pipeline YAML at container startup without baking secrets into the image.

Create a pipeline template file `pipelines.yaml.tmpl` using standard `${VAR}` syntax:

```yaml
log-pipeline:
  source:
    http:
      port: 2021
      ssl: false
  processor:
    - grok:
        match:
          message: ['%{COMMONAPACHELOG}']
  sink:
    - opensearch:
        hosts:
          - https://${OPENSEARCH_HOST}:9200
        username: ${OPENSEARCH_USER}
        password: ${OPENSEARCH_PASSWORD}
        index: ${INDEX_PREFIX}-logs
```

Use a short init step in your entrypoint wrapper or an init container to render the template before Data Prepper starts.
The simplest approach with Docker Compose uses the `dev` variant to render the template and the runtime variant to run
the result:

```yaml
services:
  data-prepper-init:
    image: dhi.io/data-prepper:<tag>-dev
    environment:
      OPENSEARCH_HOST: opensearch
      OPENSEARCH_USER: admin
      OPENSEARCH_PASSWORD: ${OPENSEARCH_PASSWORD}
      INDEX_PREFIX: prod
    volumes:
      - ./pipelines.yaml.tmpl:/tmp/pipelines.yaml.tmpl:ro
      - pipeline-config:/usr/share/data-prepper/pipelines
    entrypoint: ["bash", "-c", "envsubst < /tmp/pipelines.yaml.tmpl > /usr/share/data-prepper/pipelines/pipelines.yaml"]

  data-prepper:
    image: dhi.io/data-prepper:<tag>
    depends_on:
      data-prepper-init:
        condition: service_completed_successfully
    ports:
      - "4900:4900"
      - "2021:2021"
    volumes:
      - ./data-prepper-config.yaml:/usr/share/data-prepper/config/data-prepper-config.yaml:ro
      - pipeline-config:/usr/share/data-prepper/pipelines:ro

volumes:
  pipeline-config:
```

Alternatively, if you are running in a single-container context, use a shell wrapper script that calls `envsubst` then
`exec`s the Data Prepper entrypoint:

```bash
#!/usr/bin/env bash
set -euo pipefail
envsubst < /pipelines/pipelines.yaml.tmpl > /usr/share/data-prepper/pipelines/pipelines.yaml
exec /usr/share/data-prepper/bin/data-prepper
```

Mount this script into the container and override the entrypoint:

```bash
docker run -d --name data-prepper \
  -p 4900:4900 \
  -e OPENSEARCH_HOST=opensearch \
  -e OPENSEARCH_USER=admin \
  -e OPENSEARCH_PASSWORD=your-strong-password \
  -e INDEX_PREFIX=prod \
  -v $(pwd)/start.sh:/start.sh:ro \
  -v $(pwd)/pipelines.yaml.tmpl:/pipelines/pipelines.yaml.tmpl:ro \
  --entrypoint /start.sh \
  dhi.io/data-prepper:<tag>-dev
```

> **Note**: `envsubst` replaces every `$VAR` or `${VAR}` token it encounters. If your pipeline YAML contains
> Kubernetes-style `${node.ip}` expressions or other non-environment variable dollar-brace sequences, pass an explicit
> variable list to prevent unwanted substitution:
> `envsubst '${OPENSEARCH_HOST} ${OPENSEARCH_USER} ${OPENSEARCH_PASSWORD} ${INDEX_PREFIX}'`

### Prometheus metrics

Data Prepper exposes Prometheus-format metrics on the management port 4900 when `metricRegistries: [Prometheus]` is set
in the server configuration (the default). Scrape the metrics endpoint:

```bash
curl -k -u admin:admin https://localhost:4900/metrics/prometheus
```

In a Prometheus scrape configuration:

```yaml
scrape_configs:
  - job_name: data-prepper
    scheme: https
    tls_config:
      insecure_skip_verify: true   # Replace with ca_file pointing to your CA in production
    basic_auth:
      username: admin
      password: your-strong-password
    static_configs:
      - targets:
          - data-prepper:4900
    metrics_path: /metrics/prometheus
```

### Docker Compose with OpenSearch

The following example starts a single-node OpenSearch cluster and a Data Prepper instance wired to it. Replace
placeholder values before use.

```yaml
services:
  opensearch:
    image: dhi.io/opensearch:<tag>
    environment:
      - discovery.type=single-node
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=${OPENSEARCH_INITIAL_ADMIN_PASSWORD}
    ports:
      - "9200:9200"
    healthcheck:
      test: ["CMD-SHELL", "bash -c 'echo > /dev/tcp/localhost/9200'"]
      interval: 15s
      timeout: 5s
      retries: 10

  data-prepper:
    image: dhi.io/data-prepper:<tag>
    depends_on:
      opensearch:
        condition: service_healthy
    ports:
      - "4900:4900"
      - "2021:2021"
    volumes:
      - ./pipelines.yaml:/usr/share/data-prepper/pipelines/pipelines.yaml:ro
      - ./data-prepper-config.yaml:/usr/share/data-prepper/config/data-prepper-config.yaml:ro
```

## Migrate from opensearchproject/data-prepper

The following table lists the key differences between the upstream `opensearchproject/data-prepper` image and this
Docker Hardened Image.

| Item              | Upstream image                             | Docker Hardened Image                                                                           |
| :---------------- | :----------------------------------------- | :---------------------------------------------------------------------------------------------- |
| Base image        | Debian with standard utilities             | Minimal hardened Debian 13; no package manager, no `curl`, no `wget`                            |
| Runtime user      | UID 1000 (`data_prepper`)                  | UID 65532 (`nonroot`); update volume permissions accordingly                                    |
| Shell             | Available at runtime                       | No shell in runtime variants; use `dev` variants for shell access or Docker Debug               |
| Package manager   | `apt-get` available                        | No package manager in runtime variants                                                          |
| Entrypoint        | `/usr/share/data-prepper/bin/data-prepper` | `/usr/share/data-prepper/bin/data-prepper` (same path; bash wrapper present)                    |
| Default config    | Minimal or no default server config        | Ships `data-prepper-config.yaml` with SSL enabled, self-signed cert, `admin`/`admin` basic auth |
| Config templating | Not bundled                                | `envsubst` (from `gettext-base`) is bundled for `${VAR}` pipeline template rendering            |
| Log directory     | Varies                                     | `/var/log/data-prepper`, writable by UID 65532                                                  |

### Migration steps

1. Update the image reference in your `docker run` command or Compose file:

   ```
   # Before
   opensearchproject/data-prepper:<version>

   # After
   dhi.io/data-prepper:<tag>
   ```

1. Update volume ownership. The runtime user is now UID 65532 instead of UID 1000. Any host-mounted directories that
   Data Prepper writes to must be writable by UID 65532:

   ```bash
   chown -R 65532:65532 /host/path/to/data-prepper-volumes
   ```

1. Replace the bundled `data-prepper-config.yaml` defaults with production-grade values. At minimum, replace the
   self-signed keystore with a certificate signed by a trusted CA and change the `admin`/`admin` HTTP basic auth
   credentials.

1. Verify your pipeline configuration files are mounted at the correct paths before starting the container, since the
   runtime variant has no shell to interactively inspect.

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

### FIPS variants

FIPS variants of the Data Prepper image are available through DHI Select and DHI Enterprise subscriptions. To pull them,
mirror the repository into your own namespace and pull from your mirror. See
[Mirror a DHI repository](https://docs.docker.com/dhi/how-to/mirror/).

FIPS variants replace the standard Java cryptography with the Bouncy Castle FIPS (BC FIPS) provider and pair it with the
OpenSSL FIPS Provider for OS-level cryptographic operations. The following components are changed compared to the
standard runtime variant:

- **Java crypto provider**: BC FIPS JARs (`bc-fips`, `bctls-fips`, `bcutil-fips`, `bcpkix-fips`) are symlinked into Data
  Prepper's `lib/` directory so they appear on the classpath.
- **JRE trust store**: The BCFKS-format trust store at `/opt/java/openjdk/17-jre/lib/security/cacerts.bcfks` replaces
  the standard JKS `cacerts`. The JVM is pointed at this store via `JDK_JAVA_OPTIONS`.
- **OpenSSL FIPS Provider**: The OpenSSL FIPS module is included for OS-level operations.
- **Approved-only mode**: The environment variable `JDK_JAVA_OPTIONS` includes
  `-Dorg.bouncycastle.fips.approved_only=false`, so the BC FIPS provider is registered but does not block
  non-FIPS-approved algorithms at runtime. The reason is the vendored docker-flavor `data-prepper-config.yaml` ships SSL
  enabled with a PKCS12 keystore (`keystore.p12`), and BC FIPS rejects non-BCFKS keystores under strict approved-only
  mode — the image would fail to start the server. Same constraint kafka 4.x-fips ships with.

**To enable strict approved-only mode**: Mount a BCFKS-format keystore and a config that sets `keyStoreType: BCFKS`,
then override `JDK_JAVA_OPTIONS` (or set `JAVA_TOOL_OPTIONS=-Dorg.bouncycastle.fips.approved_only=true`) at `docker run`
time. The BC FIPS provider will then refuse any non-approved algorithm — TLS 1.0/1.1, MD5 certificate signatures, RC4,
etc. — and throw a runtime exception rather than silently proceeding. Permissive mode (the shipped default) still routes
JVM cryptography through the BC FIPS provider; it is appropriate when full approved-algorithm isolation is not required
by your compliance posture.

**Verify the FIPS attestation** by querying the signed FIPS attestation against your mirrored repository:

```bash
docker scout attest get \
  --predicate-type https://docker.com/dhi/fips/v0.1 \
  --predicate \
  <your-namespace>/dhi-data-prepper:<tag>-fips
```

**FIPS variant migration notes**: The FIPS runtime variant is a drop-in replacement for the standard runtime variant at
the container level. No changes to your pipeline YAML or `data-prepper-config.yaml` are required. The same nonroot UID
65532 and the same entrypoint are used.

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
