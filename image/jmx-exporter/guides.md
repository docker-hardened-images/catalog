## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this JMX Exporter image

This image includes:

- JMX Prometheus Standalone JAR (`jmx_prometheus_standalone.jar`) at `/opt/jmx-exporter/`
- JMX Prometheus Java Agent JAR (`jmx_prometheus_javaagent.jar`) for in-process metric collection
- Eclipse Temurin JRE 21 at `/opt/java/openjdk/21-jre`
- Example configuration files at `/opt/jmx-exporter/examples/` for Kafka, Cassandra, Zookeeper, Tomcat, Spark, ActiveMQ,
  Flink, Hazelcast, Presto, WildFly, and WebLogic
- Default entrypoint: `java -jar jmx_prometheus_standalone.jar 5556 examples/standalone_sample_config.yml`
- Working directory: `/opt/jmx-exporter`

> **Note:** Supports standalone mode (default, external process using RMI) and Java Agent mode (in-process). See
> [Run JMX Exporter as a Java Agent](#run-jmx-exporter-as-a-java-agent) for agent mode details.

## Run JMX Exporter

> **Tip:** Use `1` or `1-debian13` for the latest stable runtime. For a version-pinned tag, use `1.5.0` or
> `1.5.0-debian13`. FIPS-compliant variants require a Docker subscription — see [Image variants](#image-variants).

### Basic usage

Start the exporter with the bundled example configuration:

```bash
$ docker run --rm -p 5556:5556 dhi.io/jmx-exporter:1
```

Verify it's running:

```bash
curl localhost:5556/metrics
curl localhost:5556/-/healthy
```

> **Note:** OpenTelemetry output is disabled by default. Enable it in your configuration file. See
> [upstream documentation](https://prometheus.github.io/jmx_exporter/) for details.

### Run in standalone mode with a custom configuration

Mount your configuration file and pass it as an argument:

```bash
$ docker run --rm -p 5556:5556 \
  -v /path/to/your/jmx_exporter_config.yaml:/etc/jmx_exporter_config.yaml \
  dhi.io/jmx-exporter:1 \
  5556 /etc/jmx_exporter_config.yaml
```

> **Important:** Your configuration must include either `hostPort` or `jmxUrl` to specify the target JVM. The exporter
> exits immediately without one. Prefer `jmxUrl` for Docker networks and Kubernetes as it resolves more reliably:
>
> ```yaml
> jmxUrl: service:jmx:rmi:///jndi/rmi://your-jvm-host:9999/jmxrmi
> ssl: false
> rules:
>   - pattern: ".*"
> ```

> **Note:** The `/-/healthy` endpoint shows exporter process health, not JVM connectivity. If the target JVM is
> unreachable, `/-/healthy` still returns `Exporter is healthy.` but `jmx_scrape_error` in `/metrics` will be `1.0`.
> When scraping succeeds, `jmx_scrape_error` is `0.0`.

See [upstream documentation](https://prometheus.github.io/jmx_exporter/) for full configuration reference.

### Run JMX Exporter as a Java Agent

The image includes the Java Agent JAR at `/opt/jmx-exporter/jmx_prometheus_javaagent.jar`. Copy it into your application
image to run JMX Exporter in-process. The agent supports HTTP (default) and OpenTelemetry output modes.

Example multi-stage Dockerfile:

```dockerfile
FROM dhi.io/jmx-exporter:1 AS jmx-agent

FROM dhi.io/your-app-image:<tag>
COPY --from=jmx-agent /opt/jmx-exporter/jmx_prometheus_javaagent.jar /opt/jmx-exporter/jmx_prometheus_javaagent.jar
COPY jmx_exporter_config.yaml /etc/jmx_exporter_config.yaml

ENV JAVA_OPTS="-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=5556:/etc/jmx_exporter_config.yaml"
```

## Common JMX Exporter use cases

### Standalone exporter with a sample JVM application

Run JMX Exporter alongside a JVM application using Docker Compose. Save as `compose.yaml`:

```yaml
services:
  jmx-exporter:
    image: dhi.io/jmx-exporter:1
    container_name: jmx-exporter
    ports:
      - "5556:5556"
    volumes:
      - ./config.yaml:/opt/jmx-exporter/config.yaml
    command:
      - "5556"
      - config.yaml
    networks:
      - metrics
    depends_on:
      - example-app

  example-app:
    build: ./SimpleJMXApp
    container_name: example-app
    ports:
      - "9999:9999"
    command:
      - "java"
      - "-classpath"
      - "."
      - "-Dcom.sun.management.jmxremote=true"
      - "-Dcom.sun.management.jmxremote.authenticate=false"
      - "-Dcom.sun.management.jmxremote.local.only=false"
      - "-Dcom.sun.management.jmxremote.ssl=false"
      - "-Dcom.sun.management.jmxremote.port=9999"
      - "-Dcom.sun.management.jmxremote.rmi.port=9999"
      - "-Djava.rmi.server.hostname=example-app"
      - "SimpleJMXApp"
    networks:
      - metrics

networks:
  metrics:
    driver: bridge
```

Save the following as `config.yaml` in the same directory:

```yaml
jmxUrl: service:jmx:rmi:///jndi/rmi://example-app:9999/jmxrmi
startDelaySeconds: 5
ssl: false
lowercaseOutputName: false
lowercaseOutputLabelNames: false
rules:
  - pattern: ".*"
```

> **Important:** Use `jmxUrl` with the full RMI service URL format:
> `service:jmx:rmi:///jndi/rmi://<service-name>:<port>/jmxrmi`. This resolves correctly across Docker networks, whereas
> `hostPort` can fail due to RMI handshake issues.

Start the services:

```bash
docker compose up
```

Verify successful scraping:

```bash
curl localhost:5556/metrics | grep jmx_scrape_error
# Should show: jmx_scrape_error 0.0
```

> **Tip:** Use bundled example configs at `/opt/jmx-exporter/examples/` for Kafka, Cassandra, Zookeeper, Tomcat, Spark,
> ActiveMQ, Flink, Hazelcast, Presto, WildFly, and WebLogic. Example: `command: ["5556", "examples/kafka-2_0_0.yml"]`

### Standalone exporter in Kubernetes

Deploy using a Deployment and ConfigMap. Create a ConfigMap with your configuration (must include `hostPort` or
`jmxUrl`):

```bash
kubectl create configmap jmx-exporter-config \
  --from-file=config.yaml=/path/to/your/jmx_exporter_config.yaml
```

Or define inline:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jmx-exporter-config
  namespace: default
data:
  config.yaml: |
    hostPort: your-jvm-service:9999
    startDelaySeconds: 0
    ssl: false
    lowercaseOutputName: false
    lowercaseOutputLabelNames: false
    rules:
      - pattern: ".*"
```

Then apply the following Deployment and Service manifests:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jmx-exporter
  namespace: default
  labels:
    app: jmx-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jmx-exporter
  template:
    metadata:
      labels:
        app: jmx-exporter
    spec:
      containers:
      - name: jmx-exporter
        image: dhi.io/jmx-exporter:1
        args:
          - "5556"
          - /etc/jmx-exporter/config.yaml
        ports:
        - containerPort: 5556
          name: metrics
        securityContext:
          runAsNonRoot: true
          runAsUser: 65532
          allowPrivilegeEscalation: false
        resources:
          requests:
            cpu: "500m"
            memory: "256Mi"
          limits:
            cpu: "1"
            memory: "512Mi"
        volumeMounts:
        - name: config
          mountPath: /etc/jmx-exporter
      volumes:
      - name: config
        configMap:
          name: jmx-exporter-config
---
apiVersion: v1
kind: Service
metadata:
  name: jmx-exporter
  namespace: default
  labels:
    app: jmx-exporter
spec:
  selector:
    app: jmx-exporter
  ports:
  - name: metrics
    port: 5556
    targetPort: 5556
```

> **Note:** Set `runAsUser: 65532` when using `runAsNonRoot: true`. The image uses a named user (`nonroot`), and
> Kubernetes requires a numeric UID to verify the constraint.

### Exporter with OpenTelemetry output

Enable OpenTelemetry by configuring the `openTelemetry` section in your configuration file:

```bash
$ docker run --rm -p 5556:5556 \
  -v /path/to/otel_config.yaml:/etc/jmx_exporter_config.yaml \
  dhi.io/jmx-exporter:1 \
  5556 /etc/jmx_exporter_config.yaml
```

See [upstream documentation](https://prometheus.github.io/jmx_exporter/) for OpenTelemetry configuration details.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. The following variants are available
for this image:

| Tag                   | Aliases                                                                    | Base OS   | User            | Compliance             | Purpose                |
| --------------------- | -------------------------------------------------------------------------- | --------- | --------------- | ---------------------- | ---------------------- |
| `1.5.0-debian13`      | `1.5.0`, `1.5-debian13`, `1.5`, `1-debian13`, `1`                          | Debian 13 | nonroot (65532) | CIS                    | Production runtime     |
| `1.5.0-debian13-fips` | `1.5.0-fips`, `1.5-debian13-fips`, `1.5-fips`, `1-debian13-fips`, `1-fips` | Debian 13 | nonroot (65532) | CIS, FIPS, STIG (100%) | FIPS-compliant runtime |

> **Note:** FIPS variants require a Docker subscription. Start a 30-day free trial at [dhi.io](https://dhi.io). Dev
> variants (`*-dev`) are not currently published for this image.

### Runtime variants

Runtime variants are minimal production images that run as nonroot and exclude shells, package managers, and debugging
tools.

### FIPS variants

FIPS variants use cryptographic modules validated under FIPS 140 and are 100% STIG-compliant. Usage:

```bash
$ docker run --rm -p 5556:5556 \
  -v /path/to/your/jmx_exporter_config.yaml:/etc/jmx_exporter_config.yaml \
  dhi.io/jmx-exporter:1-debian13-fips \
  5556 /etc/jmx_exporter_config.yaml
```

## Docker Official Image vs Docker Hardened Image

If you are migrating from the Docker Official Image (DOI) `prom/jmx-exporter`, the following table summarizes the key
differences between the two images.

| Feature                 | Docker Official Image (`prom/jmx-exporter`) | Docker Hardened Image (`dhi.io/jmx-exporter`)     |
| :---------------------- | :------------------------------------------ | :------------------------------------------------ |
| Base OS                 | Alpine or Debian                            | Debian 13 (hardened)                              |
| User                    | root                                        | `nonroot` (UID 65532)                             |
| Shell                   | Included                                    | Not included (no dev variant currently published) |
| Package manager         | Included                                    | Not included (no dev variant currently published) |
| `curl` / `wget`         | Included                                    | Not included                                      |
| CIS compliance          | No                                          | Yes                                               |
| FIPS compliance         | No                                          | Yes (FIPS variant, requires subscription)         |
| STIG compliance         | No                                          | Yes (FIPS variant, requires subscription)         |
| SBOM                    | No                                          | Embedded at `/opt/docker/sbom/`                   |
| CVE patching SLA        | Community best-effort                       | Docker-backed SLA                                 |
| Entrypoint              | `java -jar jmx_prometheus_standalone.jar`   | `java -jar jmx_prometheus_standalone.jar`         |
| Default port            | 5556                                        | 5556                                              |
| Java Agent JAR          | Included                                    | Included at `/opt/jmx-exporter/`                  |
| Bundled example configs | Included                                    | Included at `/opt/jmx-exporter/examples/`         |
| Kubernetes `runAsUser`  | Not required                                | Required: `runAsUser: 65532`                      |

> **Note:** Entrypoint and default port are identical, making migration straightforward. Main differences: nonroot user,
> no shell, CIS compliance, and Kubernetes `runAsUser` requirement.

## Migrate to a Docker Hardened Image

Update your Dockerfile to use a Docker Hardened Image as the base. Key migration considerations:

| Item               | Migration note                                                                                                                                                                                         |
| :----------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace base images with Docker Hardened Images.                                                                                                                                                       |
| Package management | Runtime images don't contain package managers. Use `dev` images for build stages.                                                                                                                      |
| Nonroot user       | Runtime images run as nonroot. Ensure files and directories are accessible to the nonroot user.                                                                                                        |
| Multi-stage build  | Use `dev` images for build stages, non-dev for runtime.                                                                                                                                                |
| TLS certificates   | Standard TLS certificates are included by default.                                                                                                                                                     |
| Ports              | Nonroot users can't bind to privileged ports (\<1024) in Kubernetes or Docker Engine \<20.10. Use port 1025+ inside the container. JMX Exporter's default port (5556) is already above this threshold. |
| Entry point        | Verify and update entry points if they differ from your current image.                                                                                                                                 |
| No shell           | Runtime images don't contain shells. Use `dev` images in build stages for shell commands.                                                                                                              |

Migration steps:

1. **Find the right variant** - Inspect image tags and select the variant that meets your needs.
1. **Update base image** - Replace your Dockerfile's base image with the hardened image. Use `dev` variants for build
   stages.
1. **Update runtime image** - Use non-dev variants for the final stage in multi-stage builds.
1. **Install packages** - Only `dev` images have package managers. Install packages in build stages, then copy artifacts
   to runtime stages. Use `apt-get` for Debian-based images.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### jmx_scrape_error is 1.0

The exporter is running but cannot reach the target JVM. Common causes:

- `hostPort` or `jmxUrl` points to an unreachable host/port
- Target JVM is not running or JMX is not enabled
- On Mac/Windows, use `host.docker.internal` instead of `localhost` to reach host processes

When scraping succeeds, `jmx_scrape_error` becomes `0.0`.

### Kubernetes runAsNonRoot error

If you see `container has runAsNonRoot and image has non-numeric user (nonroot), cannot verify user is non-root`, add
`runAsUser: 65532` to your security context:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  allowPrivilegeEscalation: false
```

### Missing hostPort or jmxUrl

The exporter exits immediately if neither `hostPort` nor `jmxUrl` is in your configuration. Add one:

```yaml
hostPort: your-jvm-host:9999
```

### General debugging

Runtime images don't contain shells or debugging tools. Use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach with an ephemeral debugging environment.

### Permissions

Runtime images run as nonroot. Ensure files and directories are accessible to the nonroot user.

### Privileged ports

Nonroot users can't bind to ports below 1024 in Kubernetes or Docker Engine \<20.10. JMX Exporter's default port (5556)
is already above this threshold.

### No shell or HTTP clients

Runtime images don't include shells, `curl`, or `wget`. Use Docker Debug for temporary debugging tools.
