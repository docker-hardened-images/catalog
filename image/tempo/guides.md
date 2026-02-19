## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/tempo:<tag>`
- Mirrored image: `<your-namespace>/dhi-tempo:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Tempo image

This Docker Hardened Tempo image includes the Grafana Tempo distributed tracing backend in a single, security-hardened
package:

- `tempo` binary (`/opt/tempo/tempo`) for trace ingestion, storage, and querying
- Support for multiple tracing protocols: OpenTelemetry (gRPC and HTTP), Jaeger (Thrift HTTP and gRPC), and Zipkin
- TraceQL query language for trace-first queries
- Metrics generation from traces via the metrics-generator component
- Local and object storage backends (S3, GCS, Azure) for trace data
- TLS certificates for secure communication
- CIS benchmark compliance (runtime), FIPS 140 + STIG + CIS compliance (FIPS variant)

## Start a Tempo instance

> **Note:** Tempo requires a YAML configuration file to start. The standalone Docker command below verifies the image
> runs correctly. See the common use cases section for complete configuration examples.

Run the following command and replace `<tag>` with the image variant you want to run (for example, `2`).

```console
$ docker run --rm dhi.io/tempo:<tag> --help
```

## Tempo-specific configuration

The Tempo binary accepts several configuration flags to customize its behavior for different deployment scenarios.

### Specify a configuration file

The `-config.file` flag points Tempo to a YAML configuration file that defines receivers, storage backends, and server
settings. This flag is required for all deployments.

```console
$ docker run --rm \
  -v $(pwd)/tempo.yaml:/etc/tempo.yaml \
  dhi.io/tempo:2 \
  -config.file=/etc/tempo.yaml
```

### Set the target module

The `-target` flag controls which Tempo module to run. By default, Tempo runs in `all` mode (single binary), but you can
run individual modules for a scalable, microservice-style deployment.

Available targets include `all`, `distributor`, `ingester`, `querier`, `query-frontend`, `compactor`, and
`metrics-generator`.

```console
$ docker run --rm \
  -v $(pwd)/tempo.yaml:/etc/tempo.yaml \
  dhi.io/tempo:2 \
  -config.file=/etc/tempo.yaml \
  -target=distributor
```

This configuration is particularly useful in high-availability setups where different Tempo instances handle specific
responsibilities for improved performance and reliability.

### Override configuration with command-line flags

Individual configuration values can be overridden at the command line using dot-notation paths that correspond to the
YAML configuration structure:

```console
$ docker run --rm \
  -v $(pwd)/tempo.yaml:/etc/tempo.yaml \
  dhi.io/tempo:2 \
  -config.file=/etc/tempo.yaml \
  -server.http-listen-port=3200 \
  -distributor.receivers.otlp.protocols.grpc.endpoint=0.0.0.0:4317
```

## Common Tempo use cases

### Run Tempo with local storage for development

Tempo stores trace data on local disk or object storage. The following example shows a minimal configuration for local
development.

Create a Tempo configuration file:

```yaml
# tempo.yaml
stream_over_http_enabled: true

server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: "0.0.0.0:4317"
        http:
          endpoint: "0.0.0.0:4318"

storage:
  trace:
    backend: local
    local:
      path: /var/tempo/traces
    wal:
      path: /var/tempo/wal
```

Start Tempo with the configuration:

```console
$ docker run -d --name tempo \
  -p 3200:3200 \
  -p 4317:4317 \
  -p 4318:4318 \
  -v $(pwd)/tempo.yaml:/etc/tempo.yaml \
  -v tempo-data:/var/tempo \
  dhi.io/tempo:2 \
  -config.file=/etc/tempo.yaml
```

Verify Tempo is running:

```console
$ curl http://localhost:3200/ready
```

A successful response returns `ready`. Note that the ingester requires approximately 15 seconds to warm up after
starting. During this period, the `/ready` endpoint returns a "not ready" status, which is expected behavior.

### Deploy Tempo with Grafana for trace visualization

The following Docker Compose configuration deploys Tempo alongside Grafana with Tempo pre-configured as a datasource.

Create the Grafana datasource configuration:

```yaml
# grafana-datasources.yaml
apiVersion: 1
datasources:
  - name: Tempo
    type: tempo
    access: proxy
    url: "http://tempo:3200"
    isDefault: true
```

Create the Docker Compose file:

```yaml
# compose.yaml
services:
  tempo:
    image: dhi.io/tempo:2
    command: ["-config.file=/etc/tempo.yaml"]
    ports:
      - "3200:3200"   # Tempo API
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
    volumes:
      - ./tempo.yaml:/etc/tempo.yaml
      - tempo-data:/var/tempo

  grafana:
    image: dhi.io/grafana:12-debian13-dev
    ports:
      - "3000:3000"
    environment:
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: Admin
    volumes:
      - ./grafana-datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml
    depends_on:
      - tempo

volumes:
  tempo-data:
```

Start the stack:

```console
$ docker compose up -d
```

Access Grafana at `http://localhost:3000` and navigate to **Explore > Tempo** to query traces.

### Accept traces from multiple protocols

Configure Tempo to accept traces from OpenTelemetry, Jaeger, and Zipkin protocols simultaneously. This is useful when
migrating from one tracing system to another or when different services in your stack use different instrumentation
libraries.

Create the Tempo configuration file:

```yaml
# tempo-multi.yaml
stream_over_http_enabled: true

server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: "0.0.0.0:4317"
        http:
          endpoint: "0.0.0.0:4318"
    jaeger:
      protocols:
        thrift_http:
          endpoint: "0.0.0.0:14268"
        grpc:
          endpoint: "0.0.0.0:14250"
    zipkin:
      endpoint: "0.0.0.0:9411"

storage:
  trace:
    backend: local
    local:
      path: /var/tempo/traces
    wal:
      path: /var/tempo/wal
```

Start Tempo with all protocol ports exposed:

```console
$ docker run -d --name tempo \
  -p 3200:3200 \
  -p 4317:4317 \
  -p 4318:4318 \
  -p 9411:9411 \
  -p 14268:14268 \
  -v $(pwd)/tempo-multi.yaml:/etc/tempo.yaml \
  -v tempo-data:/var/tempo \
  dhi.io/tempo:2 \
  -config.file=/etc/tempo.yaml
```

The following table lists the available ingestion endpoints:

| Protocol           | Port  | Endpoint                             |
| :----------------- | :---- | :----------------------------------- |
| OTLP gRPC          | 4317  | `localhost:4317`                     |
| OTLP HTTP          | 4318  | `http://localhost:4318/v1/traces`    |
| Jaeger Thrift HTTP | 14268 | `http://localhost:14268/api/traces`  |
| Zipkin             | 9411  | `http://localhost:9411/api/v2/spans` |
| Tempo API / Query  | 3200  | `http://localhost:3200`              |

### Deploy Tempo in Kubernetes

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

Tempo is typically deployed as a StatefulSet or Deployment in Kubernetes with persistent storage for trace data.

> **Note:** The Docker Hardened Image uses the string `nonroot` as the user, which causes a `CreateContainerConfigError`
> with Kubernetes' `runAsNonRoot` validation. You must explicitly set `runAsUser: 65532` in the security context to
> resolve this.

The following example shows a Deployment configuration for Tempo:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tempo
  namespace: tracing
spec:
  template:
    spec:
      containers:
      - name: tempo
        image: dhi.io/tempo:<tag>
        args:
        - -config.file=/etc/tempo.yaml
        ports:
        - containerPort: 3200
          name: http
        - containerPort: 4317
          name: otlp-grpc
        - containerPort: 4318
          name: otlp-http
        securityContext:
          runAsUser: 65532
        volumeMounts:
        - name: config
          mountPath: /etc/tempo.yaml
          subPath: tempo.yaml
        - name: data
          mountPath: /var/tempo
      volumes:
      - name: config
        configMap:
          name: tempo-config
      - name: data
        persistentVolumeClaim:
          claimName: tempo-data
      imagePullSecrets:
      - name: <secret name>
```

When deploying with Helm, include the `securityContext.runAsUser` override:

```console
$ helm upgrade --install tempo grafana/tempo \
  -n tracing --create-namespace \
  --set tempo.repository=dhi.io/tempo \
  --set tempo.tag=2 \
  --set securityContext.runAsUser=65532
```

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature             | DOI (`grafana/tempo`)                | DHI (`dhi.io/tempo`)                  |
| ------------------- | ------------------------------------ | ------------------------------------- |
| User                | `10001:10001` (numeric UID)          | `nonroot` (runtime/FIPS)              |
| Shell               | No                                   | No (runtime/FIPS)                     |
| Package manager     | No                                   | No (runtime/FIPS)                     |
| Binary path         | `/tempo`                             | `/opt/tempo/tempo`                    |
| Entrypoint          | ENTRYPOINT `/tempo`                  | ENTRYPOINT `/opt/tempo/tempo`         |
| Uncompressed size   | 155 MB                               | 145 MB (runtime) / 215 MB (FIPS)      |
| Zero CVE commitment | No                                   | Yes                                   |
| FIPS variant        | No                                   | Yes (FIPS + STIG + CIS)               |
| Base OS             | Distroless (no OS labels)            | Docker Hardened Images (Debian 13)    |
| Compliance labels   | None                                 | CIS (runtime), FIPS+STIG+CIS (fips)   |
| ENV: SSL_CERT_FILE  | `/etc/ssl/certs/ca-certificates.crt` | `/etc/ssl/certs/ca-certificates.crt`  |
| Architectures       | amd64, arm64                         | amd64, arm64 (runtime) / amd64 (FIPS) |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

**Runtime variants** are designed to run Tempo in production. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the `tempo` binary (`/opt/tempo/tempo`) and TLS certificates
- Include CIS benchmark compliance (`com.docker.dhi.compliance: cis`)

**FIPS variants** include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. FIPS variants also include STIG and CIS compliance
(`com.docker.dhi.compliance: fips,stig,cis`). For example, usage of MD5 fails in FIPS variants. Use FIPS variants in
regulated environments such as FedRAMP, government, and financial services.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

> **Note:** This image currently does not provide dev variants. For debugging, use
> [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to running containers.

**Note:** Tempo is part of the Grafana observability stack. For a complete tracing pipeline, you may also want to use
Docker Hardened Images for related components such as Grafana Alloy (trace collector) and Grafana (visualization).

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or Kubernetes manifests. At
minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This and a few other
common changes are listed in the following table of migration notes:

| Item               | Migration note                                                                                                                                                              |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile or Kubernetes manifests with a Docker Hardened Image.                                                                           |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                   |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                  |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                      |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                          |
| Ports              | Non-dev hardened images run as a nonroot user by default. Tempo uses ports 3200, 4317, 4318, 9411, and 14268, all above 1024, so no privileged port issues arise.           |
| Entry point        | Docker Hardened Images may have different entry points than upstream Tempo images. Inspect entry points for Docker Hardened Images and update your deployment if necessary. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |
| Data directory     | Ensure the `/var/tempo` directory is writable by the nonroot user. When using Docker volumes this is handled automatically. For bind mounts, set ownership to UID 65532.    |

The following steps outline the general migration process.

1. **Find hardened images for your app.** The Tempo hardened image may have several variants. Inspect the image tags and
   find the image variant that meets your needs.
1. **Update the image references in your Kubernetes manifests or Compose files.** Update the image references in your
   Tempo deployment manifests to use the hardened images. If using Helm, update your values file accordingly.
1. **For custom deployments, update the runtime image in your Dockerfile.** If you're building custom images based on
   Tempo, ensure that your final image uses the hardened Tempo image as the base.
1. **Verify data directory permissions.** Ensure the `/var/tempo` data directory is writable by the nonroot user (UID
   65532). For Docker volumes this is automatic. For bind mounts, run `chown -R 65532:65532 ./tempo-data`.
1. **Test trace ingestion and querying.** After migration, test that trace ingestion from all configured protocols and
   TraceQL queries continue to function correctly with the hardened images.

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

Tempo requires write access to the `/var/tempo` directory for trace data and WAL files. When using bind mounts, ensure
correct ownership:

```console
$ chown -R 65532:65532 ./tempo-data
```

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than upstream Tempo images. Use `docker inspect` to inspect entry
points for Docker Hardened Images and update your Kubernetes deployment if necessary.
