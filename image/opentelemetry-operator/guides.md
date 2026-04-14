## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/opentelemetry-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-opentelemetry-operator:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this opentelemetry-operator image

This Docker Hardened opentelemetry-operator image includes the operator component of OpenTelemetry in a single,
security-hardened package:

- **opentelemetry-operator**: The `manager` binary built from the official
  [open-telemetry/opentelemetry-operator](https://github.com/open-telemetry/opentelemetry-operator) repository
- **OpenTelemetry Collector management**: Creates, configures, and manages OpenTelemetry Collector instances via the
  `OpenTelemetryCollector` custom resource. Use `dhi.io/opentelemetry-collector:0-debian13` as the collector image for a
  fully DHI deployment
- **Auto-instrumentation support**: Manages automatic instrumentation for Java, Python, Node.js, .NET, Go, Apache HTTPD,
  and Nginx workloads via the `Instrumentation` custom resource
- **Webhook server**: Validates and mutates OpenTelemetry custom resources via admission webhooks, listening on port
  `9443` by default
- **Metrics endpoint**: Exposes operator metrics on port `8443` (TLS-secured by default)
- **Health probe endpoint**: Exposes liveness and readiness probes on port `8081`
- **TLS support**: Standard TLS certificates included for secure communication with the Kubernetes API

## Start an opentelemetry-operator container

> **Note:** opentelemetry-operator is designed to run inside a Kubernetes cluster as part of a full OpenTelemetry
> deployment. The following standalone Docker command displays the available configuration options.

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run --rm dhi.io/opentelemetry-operator:<tag> --help
```

## Command-line flags

The `manager` binary accepts configuration via command-line flags. Commonly used flags include:

| Flag                         | Description                                                                                                                 | Default                      | Required                  |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | ------------------------- |
| `--enable-leader-election`   | Enable leader election for HA deployments — ensures only one active controller manager                                      | `false`                      | Recommended in production |
| `--webhook-port`             | Port the webhook endpoint binds to                                                                                          | `9443`                       | No                        |
| `--metrics-addr`             | Address the metrics endpoint binds to                                                                                       | `:8443`                      | No                        |
| `--health-probe-addr`        | Address the health probe endpoint binds to                                                                                  | `:8081`                      | No                        |
| `--metrics-secure`           | Enable secure serving for metrics with TLS                                                                                  | `true`                       | No                        |
| `--tls-min-version`          | Minimum TLS version                                                                                                         | `VersionTLS12`               | No                        |
| `--enable-webhooks`          | Enable admission webhooks                                                                                                   | `true`                       | No                        |
| `--collector-image`          | Default OpenTelemetry Collector image. Override with `dhi.io/opentelemetry-collector:0-debian13` for a fully DHI deployment | `ghcr.io/open-telemetry/...` | No                        |
| `--zap-log-level`            | Log verbosity: `debug`, `info`, `error`, `panic`                                                                            | `info`                       | No                        |
| `--feature-gates`            | Comma-delimited list of feature gate identifiers                                                                            | See `--help`                 | No                        |
| `--fips-disabled-components` | Disabled collector components on FIPS platforms                                                                             | `uppercase`                  | No                        |

Example:

```bash
# Display all available flags
docker run --rm dhi.io/opentelemetry-operator:<tag> --help

# Enable verbose logging
docker run --rm dhi.io/opentelemetry-operator:<tag> --zap-log-level=debug --help
```

> **Note:** Running `--help` causes the binary to exit with a panic message (`pflag: help requested`). This is normal Go
> behavior and is not an error.

## Common opentelemetry-operator use cases

### Deploy an OpenTelemetry Collector instance

The operator manages `OpenTelemetryCollector` custom resources. Once the operator is running, deploy a Collector
instance:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
  namespace: default
spec:
  image: dhi.io/opentelemetry-collector:0-debian13
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    exporters:
      debug:
        verbosity: detailed
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [debug]
```

Verify the Collector pod is running:

```bash
kubectl get pods -n default | grep otel-collector
kubectl get opentelemetrycollector -n default
```

### Enable auto-instrumentation for Java applications

The operator manages `Instrumentation` custom resources for automatic language instrumentation. To enable Java
auto-instrumentation:

> **Note:** The `Instrumentation` resource remains at `v1alpha1` in opentelemetry-operator v0.147.0.

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: java-instrumentation
  namespace: default
spec:
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  exporter:
    endpoint: http://otel-collector:4317
```

Then annotate your Java application pod to inject instrumentation automatically:

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-java: "true"
```

### Deploy with a custom Collector configuration

Deploy a Collector with batching and a remote OTLP exporter:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector-custom
  namespace: default
spec:
  image: dhi.io/opentelemetry-collector:0-debian13
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
    exporters:
      otlp:
        endpoint: jaeger:4317
        tls:
          insecure: false
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [otlp]
```

## End-to-end opentelemetry-operator deployment walkthrough

The following steps demonstrate a complete deployment and verification, validated against opentelemetry-operator
v0.147.0 and `dhi.io/opentelemetry-operator:0-debian13` with `dhi.io/opentelemetry-collector:0-debian13` — a fully DHI
deployment with zero non-DHI images.

**Prerequisites:** A running Kubernetes cluster with `kubectl` access, `cert-manager` installed (required for webhook
TLS), and the OpenTelemetry Operator CRDs installed.

**Step 1: Install cert-manager (required for webhook TLS)**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.4/cert-manager.yaml
kubectl wait --for=condition=Ready pod --all -n cert-manager --timeout=120s
```

**Step 2: Install the OpenTelemetry Operator CRDs and RBAC**

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.147.0/opentelemetry-operator.yaml
```

**Step 3: Patch the operator Deployment to use the DHI image**

```bash
kubectl set image deployment/opentelemetry-operator-controller-manager \
  manager=dhi.io/opentelemetry-operator:0-debian13 \
  -n opentelemetry-operator-system

kubectl rollout status deployment/opentelemetry-operator-controller-manager \
  -n opentelemetry-operator-system --timeout=120s
```

**Step 4: Verify the operator pod is running with the DHI image**

```bash
kubectl get pods -n opentelemetry-operator-system
kubectl get deployment opentelemetry-operator-controller-manager \
  -n opentelemetry-operator-system \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# dhi.io/opentelemetry-operator:0-debian13
```

**Step 5: Verify the operator logs**

```bash
kubectl logs -n opentelemetry-operator-system \
  deployment/opentelemetry-operator-controller-manager --tail=10
```

Expected output confirms all three endpoints are running:

```
{"level":"INFO","message":"starting manager"}
{"level":"INFO","message":"starting server","name":"health probe","addr":"[::]:8081"}
{"level":"INFO","logger":"controller-runtime.webhook","message":"Serving webhook server","host":"","port":9443}
{"level":"INFO","logger":"controller-runtime.metrics","message":"Serving metrics server","bindAddress":":8443","secure":true}
```

**Step 6: Deploy a test Collector instance**

```bash
kubectl apply -f - <<'EOF'
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-test
  namespace: default
spec:
  image: dhi.io/opentelemetry-collector:0-debian13
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
    exporters:
      debug:
        verbosity: detailed
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [debug]
EOF

kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=otel-test-collector \
  -n default --timeout=120s

kubectl get opentelemetrycollector otel-test -n default
kubectl get pods -n default | grep otel-test
```

Expected output:

```
# Operator (opentelemetry-operator-system namespace)
opentelemetry-operator-controller-manager-xxx: dhi.io/opentelemetry-operator:0-debian13

# Collector (default namespace)
otel-test-collector-xxx: dhi.io/opentelemetry-collector:0-debian13
```

**Step 7: Clean up**

```bash
kubectl delete opentelemetrycollector otel-test -n default
kubectl delete namespace opentelemetry-operator-system
kubectl delete namespace cert-manager

# Delete leftover CRDs
kubectl delete crd \
  instrumentations.opentelemetry.io \
  opampbridges.opentelemetry.io \
  opentelemetrycollectors.opentelemetry.io \
  targetallocators.opentelemetry.io \
  certificaterequests.cert-manager.io \
  certificates.cert-manager.io \
  challenges.acme.cert-manager.io \
  clusterissuers.cert-manager.io \
  issuers.cert-manager.io \
  orders.acme.cert-manager.io
```

## Official images vs Docker Hardened Images

| Feature              | DOI (`ghcr.io/open-telemetry/opentelemetry-operator/opentelemetry-operator`) | DHI (`dhi.io/opentelemetry-operator`)   |
| -------------------- | ---------------------------------------------------------------------------- | --------------------------------------- |
| User                 | `65532:65532`                                                                | `nonroot` (runtime/FIPS) / `root` (dev) |
| Shell                | None                                                                         | No (runtime/FIPS) / Yes (dev)           |
| Package manager      | None                                                                         | No (runtime/FIPS) / APT (dev)           |
| Binary path          | `/manager`                                                                   | `/manager`                              |
| Entrypoint           | `["/manager"]`                                                               | `["/manager"]`                          |
| Zero CVE commitment  | No                                                                           | Yes                                     |
| FIPS variant         | No                                                                           | Yes (subscription required)             |
| Base OS              | Distroless                                                                   | Docker Hardened Images (Debian 13)      |
| Signed provenance    | No                                                                           | Yes                                     |
| SBOM / VEX metadata  | No                                                                           | Yes                                     |
| Compliance labels    | None                                                                         | CIS (runtime)                           |
| ENV: `SSL_CERT_FILE` | Not set                                                                      | `/etc/ssl/certs/ca-certificates.crt`    |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- **Runtime variants** are designed to run the operator in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the binary

- **Build-time variants** typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- **FIPS variants** include `fips` in the variant name and tag. They use cryptographic modules validated under FIPS 140,
  a U.S. government standard for secure cryptographic operations. Pulling FIPS variants requires a Docker subscription —
  the tags return 401 without one.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or Kubernetes manifests. At
minimum, update the base image in your existing deployment to a Docker Hardened Image. Common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                             |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile or Kubernetes manifests with a Docker Hardened Image.                                                          |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                |
| Non-root user      | By default, non-dev images run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                        |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                 |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                         |
| Ports              | The operator webhook listens on port `9443`, metrics on `8443`, and health probes on `8081`. All are above 1024 and work without issues as a nonroot user. |
| Entry point        | Both the DOI and DHI use the same entrypoint `["/manager"]`. No changes required.                                                                          |
| No shell           | By default, non-dev images don't contain a shell. Use `dev` images in build stages to run shell commands and then copy artifacts to the runtime stage.     |

The following steps outline the general migration process.

1. **Find hardened images for your app.** Inspect the image tags for `dhi.io/opentelemetry-operator` and find the
   variant that meets your needs (runtime, dev, or FIPS).

1. **Update the image reference in your Kubernetes manifests or Helm values.**

   ```yaml
   # In your Deployment manifest
   containers:
     - name: manager
       image: dhi.io/opentelemetry-operator:<tag>
   ```

1. **For custom Dockerfiles, update the runtime image.** Ensure all stages use hardened images. Intermediary stages
   typically use `dev`-tagged images; your final runtime stage should use a non-dev image variant.

1. **Verify the operator starts correctly.** After migration, check the operator logs to confirm it starts and connects
   to the Kubernetes API without errors.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default, image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user.

The opentelemetry-operator requires appropriate RBAC permissions to manage `OpenTelemetryCollector`, `Instrumentation`,
and related custom resources. Ensure your service account has the necessary ClusterRole bindings.

### Privileged ports

The operator webhook listens on port `9443`, metrics on `8443`, and health probes on `8081`. All ports are above 1024
and work without issues when running as a nonroot user.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
