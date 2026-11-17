## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/redis-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-redis-operator:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Redis Operator image

The entrypoint is `/operator manager`, the command is empty, and the working directory is `/`. Runtime images run as
numeric user `65532`. Dev images run as root and include a shell.

The process listens on:

- `8080/tcp` for metrics (`--metrics-bind-address`, default `:8080`)
- `8081/tcp` for probes (`--health-probe-bind-address`, default `:8081`). The probe paths are `/healthz` and `/readyz`.
- `9443/tcp` for the admission webhook. The webhook server stays enabled unless `ENABLE_WEBHOOKS` is `false`.

The binary has no `--version` flag. Print the manager flags with `--help`. That output includes `metrics-bind-address`,
`health-probe-bind-address`, and `leader-elect`:

```bash
docker run --rm dhi.io/redis-operator:<tag> --help
```

The same binary has `manager` and `agent` subcommands. Redis init containers run `agent bootstrap`. That command has a
`--sentinel` flag, which writes Sentinel configuration instead of Redis configuration:

```bash
docker run --rm --entrypoint /operator dhi.io/redis-operator:<tag> agent bootstrap --help
```

## Deploy Redis Operator on Kubernetes

Use the published Helm chart `redis-operator` version `0.26.1` (appVersion `0.26.0`) from
https://ot-container-kit.github.io/helm-charts. This is the upstream OpsTree chart, not a catalog chart in this
repository.

The Deployment command is `/operator manager`. With chart defaults the arguments include `--leader-elect` and, because
metrics are enabled, `--metrics-bind-address=:8080`. The chart also passes `--kube-client-timeout=60s` and
`--max-concurrent-reconciles=3` from `manager.config`. The chart webhook default is false, so the rendered Deployment
sets `ENABLE_WEBHOOKS` to `false` and omits container port `9443`.

Set `redisOperator.imageName`, `redisOperator.imageTag`, and `redisOperator.initContainerImageTag` together. DHI tags
have no `v` prefix. The tag shape is `0.26.0`, not `v0.26.0`. An empty `imageTag` becomes `v` plus the chart appVersion
(`v0.26.0`). `initContainerImageTag` defaults to `v0.26.0`, so changing only `imageTag` leaves the init container on
that default.

```yaml
redisOperator:
  imageName: dhi.io/redis-operator
  imageTag: "<tag>"
  initContainerImageTag: "<tag>"
```

Add the chart repository, then render the Deployment. In the output, the manager `image` and `INIT_CONTAINER_IMAGE` use
the same name and tag:

```bash
helm repo add ot-helm https://ot-container-kit.github.io/helm-charts
```

```bash
helm template redis-operator ot-helm/redis-operator \
  --version 0.26.1 \
  --set redisOperator.imageName=dhi.io/redis-operator \
  --set redisOperator.imageTag=<tag> \
  --set redisOperator.initContainerImageTag=<tag>
```

### Redis server and exporter images

This operator image does not contain Redis. Each Redis custom resource chooses its own server and exporter images. Set
`kubernetesConfig.image` to `dhi.io/redis:<tag>` and `redisExporter.image` to `dhi.io/redis-exporter:<tag>`. The Redis
image runs as numeric user `65532`.

`dhi.io/redis` runtime images have no shell. When a Redis custom resource omits probes, operator v0.26.0
(`internal/k8sutils/statefulset.go`) injects readiness and liveness probes that run `sh -ec` around `redis-cli ping`.
Those probes never succeed, so the pods stay unready. The image's `/etc/redis/conf.d/docker.conf` also leaves
`protected-mode` on, so a client in another pod is refused. Exec `/usr/local/bin/redis-cli` directly for both probes,
and mount a `docker.conf` that sets `protected-mode no` over that path. The data directory uses an emptyDir so this
example does not need a StorageClass.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-redis-conf
data:
  docker.conf: |
    daemonize no
    bind 0.0.0.0 -::1
    protected-mode no
    logfile ""
---
apiVersion: redis.redis.opstreelabs.in/v1beta2
kind: Redis
metadata:
  name: example
spec:
  podSecurityContext:
    runAsUser: 65532
    fsGroup: 65532
  kubernetesConfig:
    image: dhi.io/redis:<tag>
  redisExporter:
    enabled: true
    image: dhi.io/redis-exporter:<tag>
  readinessProbe:
    exec:
      command:
        - /usr/local/bin/redis-cli
        - -h
        - 127.0.0.1
        - ping
    initialDelaySeconds: 2
    periodSeconds: 3
    failureThreshold: 20
  livenessProbe:
    exec:
      command:
        - /usr/local/bin/redis-cli
        - -h
        - 127.0.0.1
        - ping
    initialDelaySeconds: 15
    periodSeconds: 10
    failureThreshold: 6
  storage:
    volumeMount:
      volume:
        - name: redis-data
          emptyDir: {}
        - name: redis-conf
          configMap:
            name: example-redis-conf
      mountPath:
        - name: redis-data
          mountPath: /data
        - name: redis-conf
          mountPath: /etc/redis/conf.d/docker.conf
          subPath: docker.conf
```

This catalog does not publish a Redis Sentinel image. Set the Sentinel server image on the Redis Sentinel custom
resource. Sentinel pods use the same default `sh -ec` probes, so a shell-less image stays unready until those probes
exec the server binary directly. The operator's `sh -c` preStop hook is not on the Sentinel container. It is installed
on cluster pods, and on replication pods that name a Sentinel service, and those pods need a shell or an explicit
lifecycle hook.

### Raw manifests

A manifest that leaves `INIT_CONTAINER_IMAGE` unset still falls back to the compiled default
`quay.io/opstree/redis-operator:latest`. Set `INIT_CONTAINER_IMAGE` to the same `dhi.io/redis-operator:<tag>` you use
for the manager.

## Environment variables

This image sets `SSL_CERT_FILE` only. The Helm chart owns the other variables in this table. The image does not set
`ENABLE_WEBHOOKS`, `WATCH_NAMESPACE`, `INIT_CONTAINER_IMAGE`, `FEATURE_GATES`, or `SERVICE_DNS_DOMAIN`.

| Variable               | Set by     | Description                                                                                                                                                                                                                                   |
| ---------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SSL_CERT_FILE`        | This image | CA bundle path. The image sets `/etc/ssl/certs/ca-certificates.crt`. That file is present on Debian and Alpine.                                                                                                                               |
| `ENABLE_WEBHOOKS`      | Helm chart | From `redisOperator.webhook`. The chart default is `false`, so the Deployment sets `ENABLE_WEBHOOKS=false`. The process listens on `9443` unless the value is `false`. Certificates are required only when `redisOperator.webhook` is `true`. |
| `WATCH_NAMESPACE`      | Helm chart | Set when `redisOperator.watchNamespace` is non-empty. Limits the namespaces the operator watches.                                                                                                                                             |
| `INIT_CONTAINER_IMAGE` | Helm chart | `imageName` plus `initContainerImageTag`. Independent of `imageTag` while `initContainerImageTag` is set. When a raw manifest leaves it unset, the operator uses `quay.io/opstree/redis-operator:latest`.                                     |
| `FEATURE_GATES`        | Helm chart | Set from the `featureGates` map when that map is non-empty. An unknown gate makes the operator exit at startup.                                                                                                                               |
| `SERVICE_DNS_DOMAIN`   | Helm chart | From `redisOperator.serviceDNSDomain`. The chart default is `cluster.local`.                                                                                                                                                                  |

## Image tags

Debian publishes the bare major tag `0`, along with `0.26` and `0.26.0`, and distro-qualified tags such as
`0.26.0-debian13`. Alpine tags are distro-suffixed, for example `0.26.0-alpine3.24`, and do not include the bare major
tag. Dev tags add `-dev`. Those images run as root and include a shell. FIPS runtime tags add `-fips`, and FIPS dev tags
add `-fips-dev`, on both Debian and Alpine.

## Migrate from quay.io/opstree/redis-operator

`quay.io/opstree/redis-operator:v0.26.0` and this image use the same entrypoint, `/operator manager`, and the same
working directory, `/`. The upstream config user is `65532:65532`. This image runs as numeric user `65532`, the same uid
and primary gid. Neither image defines a healthcheck.

On the Helm chart, set `imageName`, `imageTag`, and `initContainerImageTag` together, and use a DHI tag with no `v`
prefix. On Redis custom resources, set `kubernetesConfig.image` to `dhi.io/redis:<tag>` and `redisExporter.image` to
`dhi.io/redis-exporter:<tag>`, and apply the probe and `protected-mode` overrides in
[Redis server and exporter images](#redis-server-and-exporter-images). Sentinel custom resources need the same probe
override.

## Troubleshooting

### No version flag

There is no `--version` flag. Upstream ldflags are only `-s -w`, so the binary does not print a version string. Use
`--help`, including `agent bootstrap --help` for the init-container command.

### Webhooks

The chart default `redisOperator.webhook` is `false`, and the chart then sets `ENABLE_WEBHOOKS=false`. Turn the webhook
on by setting `redisOperator.webhook` to `true`. Certificates are required only when that value is `true`. When the
webhook is true and `certmanager.enabled` is false, Helm generates a self-signed certificate. When `certmanager.enabled`
is true, cert-manager supplies the certificate.

### Init-container tag

`initContainerImageTag` is separate from `imageTag`. The chart default for `initContainerImageTag` is `v0.26.0`. Set
`imageName`, `imageTag`, and `initContainerImageTag` to the same DHI name and tag. A tag such as `0.26.0` is a DHI tag.
`v0.26.0` is the upstream chart default.

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
