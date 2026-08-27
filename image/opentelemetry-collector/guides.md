## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This guide provides practical examples for using the OpenTelemetry Collector Hardened Image to collect, process, and
export telemetry data (traces, metrics, and logs).

## What's included in this OpenTelemetry Collector image

This Docker Hardened OpenTelemetry Collector image includes:

- The `otelcol` binary (core distribution) or `otelcol-contrib` binary (contrib distribution) built from the official
  OpenTelemetry Collector releases.
- A default configuration installed at `/etc/otelcol/config.yaml` (core) or `/etc/otelcol-contrib/config.yaml`
  (contrib).
- The entrypoint is the otelcol binary at `/usr/local/bin/otelcol` (or `/usr/local/bin/otelcol-contrib` for contrib);
  the default command loads the configuration from the installed config file.

## Start an OpenTelemetry Collector container

```bash
docker run -d --name otel-collector \
    -p 4317:4317 \
    -p 4318:4318 \
    -p 8888:8888 \
    -p 13133:13133 \
    dhi.io/opentelemetry-collector:<tag>
```

## Common use cases

### Run with Docker Compose

```bash
cat <<EOF > docker-compose.yaml
services:
  otel-collector:
    image: dhi.io/opentelemetry-collector:<tag>
    ports:
      - "4317:4317"
      - "4318:4318"
      - "8888:8888"
      - "13133:13133"
EOF
```

Start the collector:

```bash
docker compose up -d
```

### Run with Docker Compose (Custom Configuration)

The default configuration binds the health check extension to `localhost:13133`, which is not accessible from outside
the container. To expose health checks externally, use a custom configuration.

Create `otel-config.yaml`:

```bash
cat <<EOF > otel-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:

exporters:
  debug:
    verbosity: detailed

extensions:
  health_check:
    endpoint: 0.0.0.0:13133

service:
  extensions: [health_check]
  telemetry:
    metrics:
      readers:
        - pull:
            exporter:
              prometheus:
                host: 0.0.0.0
                port: 8888
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
EOF
```

Create `docker-compose.yaml`:

```bash
cat <<EOF > docker-compose.yaml
services:
  otel-collector:
    image: dhi.io/opentelemetry-collector:<tag>
    ports:
      - "4317:4317"
      - "4318:4318"
      - "8888:8888"
      - "13133:13133"
    volumes:
      - ./otel-config.yaml:/etc/otelcol/config.yaml:ro
EOF
```

Start the collector:

```bash
docker compose up -d
```

Verify the health check endpoint:

```bash
curl http://localhost:13133/
{"status":"Server available","upSince":"2026-01-26T07:26:00.886986636Z","uptime":"5.162434461s"}
```

### Run with Docker Compose (Full Stack with Jaeger)

To test the OpenTelemetry Collector with a tracing backend, use this complete Docker Compose configuration:

Create `otel-config.yaml`:

```bash
cat <<EOF > otel-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:

exporters:
  debug:
    verbosity: detailed
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true

extensions:
  health_check:
    endpoint: 0.0.0.0:13133

service:
  extensions: [health_check]
  telemetry:
    metrics:
      readers:
        - pull:
            exporter:
              prometheus:
                host: 0.0.0.0
                port: 8888
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug, otlp/jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
EOF
```

Create `docker-compose.yaml`:

```bash
cat <<EOF > docker-compose.yml
services:
  otel-collector:
    image: dhi.io/opentelemetry-collector:<tag>
    ports:
      - "4317:4317"
      - "4318:4318"
      - "8888:8888"
      - "13133:13133"
    volumes:
      - ./otel-config.yaml:/etc/otelcol/config.yaml:ro
    depends_on:
      - jaeger
    restart: unless-stopped

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"
    environment:
      - COLLECTOR_OTLP_ENABLED=true
EOF
```

Start the stack:

```bash
docker compose up -d
```

Verify the collector is running:

```bash
curl http://localhost:13133/
{"status":"Server available","upSince":"...","uptime":"..."}
```

Send a test trace:

```bash
curl -X POST http://localhost:4318/v1/traces \
    -H "Content-Type: application/json" \
    -d '{
      "resourceSpans": [{
        "resource": {
          "attributes": [{
            "key": "service.name",
            "value": {"stringValue": "test-service"}
          }]
        },
        "scopeSpans": [{
          "spans": [{
            "traceId": "5B8EFFF798038103D269B633813FC60C",
            "spanId": "EEE19B7EC3C1B174",
            "name": "test-span",
            "kind": 1,
            "startTimeUnixNano": "1704067200000000000",
            "endTimeUnixNano": "1704067201000000000"
          }]
        }]
      }]
    }'
```

Access the Jaeger UI at `http://localhost:16686` to view the trace.

### Use OpenTelemetry Collector in Kubernetes

To use the OpenTelemetry Collector hardened image in Kubernetes, set up authentication and update your Kubernetes
deployment.

```bash
cat <<EOF > otel-collector.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: otel-collector
          image: dhi.io/opentelemetry-collector:<tag>
          ports:
            - containerPort: 4317
              name: otlp-grpc
            - containerPort: 4318
              name: otlp-http
            - containerPort: 8888
              name: metrics
            - containerPort: 13133
              name: health
      imagePullSecrets:
        - name: <your-registry-secret>
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: default
spec:
  ports:
    - port: 4317
      targetPort: 4317
      name: otlp-grpc
    - port: 4318
      targetPort: 4318
      name: otlp-http
    - port: 8888
      targetPort: 8888
      name: metrics
  selector:
    app: otel-collector
EOF
```

Then apply the manifest to your Kubernetes cluster:

```bash
kubectl apply -n default -f otel-collector.yaml
```

Verify the deployment:

```console
$ kubectl get pods -n default
NAME                              READY   STATUS    RESTARTS   AGE
otel-collector-6959756cc4-bbkp9   1/1     Running   0          38s
```

Access the metrics:

```console
$ kubectl port-forward -n default deployment/otel-collector 8888:8888
$ curl http://localhost:8888/metrics | head -10
```

For examples of how to configure the OpenTelemetry Collector itself, see the
[OpenTelemetry Collector documentation](https://opentelemetry.io/docs/collector/).

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened OpenTelemetry Collector | Docker Hardened OpenTelemetry Collector                    |
| --------------- | ------------------------------------ | ---------------------------------------------------------- |
| Base image      | Alpine/Debian                        | Debian 13 hardened base                                    |
| Security        | Standard image                       | Hardened build with security patches and security metadata |
| Shell access    | Shell available                      | No shell                                                   |
| Package manager | Package manager available            | No package manager                                         |
| User            | Varies                               | Runs as nonroot user (UID 65532)                           |
| Binary location | `/otelcol`                           | `/usr/local/bin/otelcol`                                   |
| Config location | `/etc/otelcol/config.yaml`           | `/etc/otelcol/config.yaml`                                 |
| Attack surface  | Standard utilities included          | Only otelcol binary, no additional utilities               |
| Debugging       | Shell and utilities available        | Use Docker Debug or image mount for troubleshooting        |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```console
$ docker debug otel-collector
```

Or mount debugging tools with the image mount feature:

```console
$ docker run --rm -it --pid container:otel-collector \
    --mount=type=image,source=dhi.io/busybox:<tag>,destination=/dbg,ro \
    dhi.io/opentelemetry-collector:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

The OpenTelemetry Collector image provides runtime, dev, and FIPS variants. Runtime variants are designed to run your
application in production. These images are intended to be used either directly or as the `FROM` image in the final
stage of a multi-stage build. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

The OpenTelemetry Collector is available in two distributions:

- **Core distribution**: Uses the `otelcol` binary with config at `/etc/otelcol/config.yaml`
- **Contrib distribution**: Uses the `otelcol-contrib` binary with additional receivers, exporters, and processors;
  config at `/etc/otelcol-contrib/config.yaml`

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

### FIPS variants

FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
validated under FIPS 140, a U.S. government standard for secure cryptographic operations. Docker Hardened OpenTelemetry
Collector images include FIPS-compliant variants for environments requiring Federal Information Processing Standards
compliance.

Steps to verify FIPS:

```console
# Compare image sizes (FIPS variants are larger due to FIPS crypto libraries)
$ docker images | grep opentelemetry-collector

# Verify FIPS compliance using image labels
$ docker inspect dhi.io/opentelemetry-collector:<tag>-fips \
    --format '{{index .Config.Labels "com.docker.dhi.compliance"}}'
fips,stig,cis
```

Runtime requirements specific to FIPS:

- FIPS mode enforces stricter cryptographic standards
- Use FIPS variants when connecting to backends with FIPS-compliant TLS
- Required for deployments in US government or regulated environments
- Only FIPS-approved cryptographic algorithms are available for TLS connections

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshoot migration

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
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
