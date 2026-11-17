## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/logging-operator:6`
- Mirrored image: `<your-namespace>/dhi-logging-operator:6`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Logging operator is a Kubernetes operator that deploys and configures Fluent Bit, Fluentd and syslog-ng from `Logging`,
`Flow` and `Output` custom resources. This image is the operator itself. It is the catalog replacement for
`ghcr.io/kube-logging/logging-operator` on the 6.x line. The Fluentd, Fluent Bit, syslog-ng and sidecar images the
operator deploys are separate images and are not part of this image.

Debian 13 is the primary runtime tag: `dhi.io/logging-operator:6`. The Alpine 3.24 runtime tag is
`dhi.io/logging-operator:6-alpine3.24`. Both are also published with the full version of the current 6.x release.

## Start a Logging operator image

The entrypoint is `/usr/local/bin/logging-operator`, a symlink to `/usr/bin/logging-operator`. The upstream path
`/manager` is kept as a second symlink to the same binary, so `--entrypoint /manager` and any manifest that runs
`/manager` keep working. The image sets no command, no exposed ports and no health check, as in the upstream image. The
only environment variable is `PATH`; FIPS tags also set the OpenSSL variables `OPENSSL_CONF` and `OPENSSL_MODULES`, and
Debian FIPS tags add `SSL_CERT_FILE`. The working directory is `/`. The FIPS claim covers the operator binary; the
Fluentd, Fluent Bit and syslog-ng images it deploys are separate images.

### Basic usage

The operator is a long-running controller and needs a Kubernetes API. `-h` prints usage to standard error and exits 0.
There is no version flag. Flags use Go's `flag` package, so the printed form is a single dash, for example
`-watch-namespace`. A flag that does not exist exits 2, and starting without a cluster configuration exits 1.

```bash
docker run --rm dhi.io/logging-operator:6 -h
```

The flags are the same as in the upstream image:

| Flag                                 | Purpose                                                                |
| :----------------------------------- | :--------------------------------------------------------------------- |
| `-metrics-addr`                      | Metrics endpoint address, default `:8080`.                             |
| `-health-probe-bind-address`         | `/healthz` and `/readyz` address, default `:8081`.                     |
| `-enable-leader-election`            | Elect one active manager when you run more than one replica.           |
| `-watch-namespace`                   | Reconcile only objects in this namespace.                              |
| `-watch-logging-name`                | Reconcile only objects that belong to this `Logging` resource.         |
| `-watch-labeled-children`            | Watch only child resources that carry the operator's name label.       |
| `-watch-labeled-secrets`             | Watch only secrets labeled `logging.banzaicloud.io/watch: enabled`.    |
| `-sync-period`                       | Minimum reconcile frequency as a Go duration. The default is 10 hours. |
| `-output-format`                     | `json` or `console` log output.                                        |
| `-verbose`, `-klogLevel`             | Log verbosity.                                                         |
| `-finalizer-cleanup`                 | Remove finalizers from `Logging` resources at shutdown.                |
| `-enable-telemetry-controller-route` | Enable the Telemetry Controller route for `Logging` resources.         |
| `-pprof`                             | Enable pprof on the metrics address.                                   |
| `-kubeconfig`                        | Kubeconfig path, only for running outside a cluster.                   |

Runtime images run as user 65532 and contain no shell. Dev tags run as root and include a shell and a package manager.

### Install with the upstream Helm chart

The upstream chart installs `ghcr.io/kube-logging/logging-operator` through `image.repository` and `image.tag`. Point
those values at this image. The chart's default arguments (`-enable-leader-election=true`), its `/healthz` and `/readyz`
probes on port 8081, and its RBAC stay as they are. Use the chart version that matches the image version.

```bash
helm install logging-operator oci://ghcr.io/kube-logging/helm-charts/logging-operator \
  --version <version> \
  --namespace logging-operator --create-namespace \
  --set image.repository=dhi.io/logging-operator \
  --set image.tag=6 \
  --set 'imagePullSecrets[0].name=dhi-pull-secret'
```

Replace `<version>` with the chart version, for example the full version of the 6.x release you run, and create the
`dhi-pull-secret` image pull secret for `dhi.io` in the `logging-operator` namespace first. Use tag `6-alpine3.24` for
the Alpine runtime image.

Check that the operator is ready:

```bash
kubectl --namespace logging-operator rollout status deployment/logging-operator
```

### Create a logging pipeline

The upstream `all-to-file` sample creates a `Logging` resource with Fluentd, a `FluentbitAgent`, a `Flow` that selects
every log and an `Output` that writes to a file. Save it as `all-to-file.yaml` and apply it.

```yaml
apiVersion: logging.banzaicloud.io/v1beta1
kind: Logging
metadata:
  name: all-to-file
spec:
  fluentd: {}
  controlNamespace: default
---
apiVersion: logging.banzaicloud.io/v1beta1
kind: FluentbitAgent
metadata:
  name: all-to-file
spec:
  positiondb:
    hostPath:
      path: ""
  bufferStorageVolume:
    hostPath:
      path: ""
---
apiVersion: logging.banzaicloud.io/v1beta1
kind: Flow
metadata:
  name: all
spec:
  filters:
    - tag_normaliser: {}
  match:
    - select: {}
  localOutputRefs:
    - file
---
apiVersion: logging.banzaicloud.io/v1beta1
kind: Output
metadata:
  name: file
spec:
  file:
    path: /tmp/logs/${tag}
    append: true
    buffer:
      timekey: 1m
      timekey_wait: 10s
      timekey_use_utc: true
```

```bash
kubectl apply -f all-to-file.yaml
kubectl --namespace default get statefulset all-to-file-fluentd
kubectl --namespace default get daemonset all-to-file-fluentbit
```

The operator creates the `all-to-file-fluentd` StatefulSet and the `all-to-file-fluentbit` DaemonSet and renders the
`Output` into the Fluentd configuration. The images in those workloads are the operator's defaults: Fluentd
`ghcr.io/kube-logging/logging-operator/fluentd:<version>-full`, and the config reloader and buffer metrics sidecars at
the operator's own version. Set `spec.fluentd.image`, `spec.fluentbit.image` and the sidecar image fields of the
`Logging` resource to use other images, for example images you mirror.

### Run with a restricted security context

The image runs as the numeric user 65532 and the operator does not write to its root filesystem, so it runs under the
restricted Pod Security Standard. These chart values keep the chart's probes and RBAC and tighten the container:

```yaml
image:
  repository: dhi.io/logging-operator
  tag: "6"
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  capabilities:
    drop:
      - ALL
```

### Tailer webhook

The tailer pod mutation webhook is off by default. Set `ENABLE_WEBHOOKS=true` to serve it over TLS at `/tailer-webhook`,
with `WEBHOOK_PORT` selecting the port and the certificate and key mounted as `tls.crt` and `tls.key` in
`/tmp/k8s-webhook-server/serving-certs/`. The upstream chart does not enable it.

### Dev variants

Dev images run as root and include a shell and a package manager. `dhi.io/logging-operator:6-dev` is Debian 13 with
`bash` and `apt-get`. `dhi.io/logging-operator:6-alpine3.24-dev` is Alpine 3.24 with `bash` and `apk`.

```bash
docker run --rm --entrypoint bash dhi.io/logging-operator:6-dev -c 'command -v logging-operator && logging-operator -h 2>&1 | grep -q -- -watch-namespace'
```

## Non-hardened images vs. Docker Hardened Images

The upstream image is a distroless static image whose user is root (uid 0). Runtime tags of this image run as the
numeric user 65532, contain no shell, and ship the same single operator binary. Allow uid 65532 in manifests that set
`runAsUser`, `fsGroup` or similar, and do not rely on the process being root.

The upstream image publishes the tags `6.9.0` and `latest`. This image publishes `6`, `6.9` and `6.9.0` with the distro
and variant suffixes, and no `latest` tag. Pin `6` or the full version.

The entrypoint is `/usr/local/bin/logging-operator` instead of `/manager`. The path `/manager` still resolves to the
same binary. A manifest that overrides `command` or `args` with `/manager` and its flags works unchanged.

The upstream image sets `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt`. Non-FIPS tags and Alpine FIPS tags of this
image do not set it. The bundle is at the same path, and Go reads it by default. Debian FIPS tags set it to the same
path.

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
