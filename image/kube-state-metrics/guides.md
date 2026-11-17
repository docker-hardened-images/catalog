## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this kube-state-metrics Hardened image

kube-state-metrics is a Kubernetes add-on that listens to the Kubernetes API server and generates metrics about the
state of cluster objects (pods, deployments, nodes, services, etc.). It does not modify cluster state — it only reads
from the API and exposes a Prometheus-format `/metrics` endpoint for scraping.

This Docker Hardened kube-state-metrics image includes:

- `kube-state-metrics` (the metrics generator binary, set as the image entrypoint with default flags
  `--port=8080 --telemetry-port=8081`)

The image exposes two TCP ports: `8080` for the cluster-state metrics scrape endpoint, and `8081` for
kube-state-metrics' own self-metrics (telemetry about the exporter itself). The image is designed to run inside a
Kubernetes cluster, where it authenticates to the API server using a ServiceAccount token mounted into the pod.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

# Start a kube-state-metrics instance

The image's entrypoint is `kube-state-metrics --port=8080 --telemetry-port=8081`. When you run the container without
additional arguments, it starts the metrics server with defaults. Outside a Kubernetes cluster, the binary fails fast
with a configuration error because it has no API server to connect to:

```bash
$ docker run --rm dhi.io/kube-state-metrics:<tag>
```

This is by design — kube-state-metrics is intended to run as a pod inside the cluster it monitors. See
[Deploy to Kubernetes](#deploy-to-kubernetes) below for the recommended installation pattern.

## Display version information

To check the binary version, override the entrypoint to drop the baked-in `--port` flags. The `version` subcommand does
not accept the global flags, so running it without `--entrypoint` fails:

```bash
$ docker run --rm --entrypoint kube-state-metrics dhi.io/kube-state-metrics:<tag> version
kube-state-metrics, version 2.17.0 (branch: dhi, ...)
```

# Common kube-state-metrics use cases

## Deploy to Kubernetes

kube-state-metrics is typically installed via the upstream `prometheus-community/kube-state-metrics` Helm chart. The
chart handles ServiceAccount creation, RBAC permissions, the Deployment, and a Service for scraping. To use the Docker
Hardened Image, override the chart's image fields to point at `dhi.io`.

**Step 1: Create an image pull secret.** The DHI registry requires authentication for cluster pulls:

```bash
$ kubectl create secret docker-registry helm-pull-secret \
    --docker-server=dhi.io \
    --docker-username=<Docker username> \
    --docker-password=<Docker token> \
    --docker-email=<Docker email>
```

Use a Docker Hub personal access token (not your account password). For more detail, see
[DHI authentication in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/).

**Step 2: Add the upstream Helm repository:**

```bash
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
$ helm repo update prometheus-community
```

**Step 3: Install the chart with DHI image overrides:**

```bash
$ helm install ksm prometheus-community/kube-state-metrics \
    --set image.registry=dhi.io \
    --set image.repository=kube-state-metrics \
    --set image.tag=<tag> \
    --set "imagePullSecrets[0].name=helm-pull-secret"
```

Note that DHI tags omit the `v` prefix that the upstream chart uses by default (for example, `2.17` instead of
`v2.17.0`). Always override `image.tag` explicitly when using the upstream chart.

**Step 4: Verify the deployment:**

```bash
$ kubectl get pod -l app.kubernetes.io/instance=ksm
NAME                                      READY   STATUS    RESTARTS   AGE
ksm-kube-state-metrics-5b56fd95d8-8cqmh   1/1     Running   0          21s
```

Confirm the running pod is the digest-pinned DHI image:

```bash
$ kubectl get pod -l app.kubernetes.io/instance=ksm \
    -o jsonpath='{.items[0].spec.containers[0].image}'
dhi.io/kube-state-metrics:<tag>
```

To uninstall:

```bash
$ helm uninstall ksm
```

## Scrape metrics with Prometheus

The chart creates a `Service` of type `ClusterIP` named `ksm-kube-state-metrics` exposing port 8080. Prometheus can
scrape this service directly:

```yaml
scrape_configs:
  - job_name: 'kube-state-metrics'
    static_configs:
      - targets: ['ksm-kube-state-metrics.default.svc.cluster.local:8080']
```

If you use the Prometheus Operator, the chart can also create a `ServiceMonitor` resource by setting
`prometheus.monitor.enabled=true` during install. See the chart's values reference for full options:

```bash
$ helm show values prometheus-community/kube-state-metrics
```

## Inspect available metrics

To preview the metrics output without setting up a full Prometheus stack, port-forward to the kube-state-metrics pod:

```bash
$ POD=$(kubectl get pod -l app.kubernetes.io/instance=ksm \
    -o jsonpath='{.items[0].metadata.name}')
$ kubectl port-forward $POD 8080:8080
```

Then in another terminal:

```bash
$ curl http://localhost:8080/metrics | grep ^kube_pod_status_phase | head
```

Common metric families produced by kube-state-metrics include `kube_pod_*`, `kube_deployment_*`, `kube_node_*`,
`kube_service_*`, `kube_configmap_*`, `kube_secret_*`, `kube_persistentvolume_*`, and `kube_job_*`. See the upstream
documentation for the full list:
https://github.com/kubernetes/kube-state-metrics/blob/main/docs/README.md#exposed-metrics

# Non-hardened images vs Docker Hardened Images

## Key differences

| Feature         | Docker Official kube-state-metrics  | Docker Hardened kube-state-metrics                  |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened Debian 13 base                    |
| Shell access    | Full shell available                | No shell in runtime variants                        |
| Package manager | `apk` / `apt` available             | No package manager in runtime variants              |
| User            | Runs as a low-numbered nonroot UID  | Runs as nonroot user (UID 65532)                    |
| Attack surface  | Larger due to additional utilities  | Minimal — binary only, no other tools               |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| Compliance      | None                                | CIS; FIPS 140-3 and STIG in FIPS variants           |
| Attestations    | None                                | SBOM, provenance, VEX metadata                      |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened image contains only the `kube-state-metrics` binary and its required libraries — no shell, no coreutils, no
package manager, no editors. Common debugging methods for applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session. For example:

```bash
$ docker debug ksm-pod
```

For operational visibility without a shell, kube-state-metrics' own telemetry endpoint on port 8081 (`/metrics`) exposes
self-metrics about scrape duration, request counts, and resource usage of the exporter itself.

# Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (UID 65532)
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants include `dev` in the variant name and are intended for use in the first stage of a multi-stage
Dockerfile. These images typically:

- Run as the root user
- Include a shell (`bash` and `/bin/sh`) and a package manager (`apt`)
- Are used to build or compile applications

The kube-state-metrics image is published in the following variant combinations:

| Variant           | Tag pattern                                         | User    | Compliance      | Availability      |
| ----------------- | --------------------------------------------------- | ------- | --------------- | ----------------- |
| Runtime           | `<version>`, `<version>-debian13`                   | nonroot | CIS             | Public            |
| Build-time (dev)  | `<version>-dev`, `<version>-debian13-dev`           | root    | CIS             | Public            |
| Runtime + FIPS    | `<version>-fips`, `<version>-debian13-fips`         | nonroot | CIS, FIPS, STIG | Subscription only |
| Build-time + FIPS | `<version>-fips-dev`, `<version>-debian13-fips-dev` | root    | CIS, FIPS, STIG | Subscription only |

DHI tags use the upstream version number directly with no `v` prefix (for example, `2.17`, not `v2.17.0`). Tags also
include rolling major-version aliases — `2` always points to the latest 2.x release, and `2.17` to the latest 2.17.x
patch.

To view all published tags and get more information about each variant, select the **Tags** tab for this repository.

# FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

The kube-state-metrics FIPS variants are available through DHI Select and DHI Enterprise subscriptions only. To use
them, mirror the repository into your own namespace and pull from your mirror. See
[Mirror a DHI repository](https://docs.docker.com/dhi/how-to/mirror/).

FIPS variants of the kube-state-metrics image are drop-in replacements for the standard runtime variant — same
entrypoint, same ports, same nonroot UID 65532. kube-state-metrics does not require any FIPS-specific configuration
flags. TLS operations for the metrics server (when configured via `--tls-config` and `--web.tls-cert-file`)
automatically use the FIPS-validated cryptographic providers.

## What changes in FIPS mode

Compared to the standard runtime variant:

- **Cryptographic modules**: OpenSSL FIPS Provider is used for TLS operations
- **Available algorithms**: only FIPS 140-approved algorithms are available; non-approved algorithms (such as MD5) fail
  at runtime
- **Image size**: slightly larger due to the FIPS provider module
- **Compliance labels**: carries `com.docker.dhi.compliance=fips,stig,cis`
- **Everything else**: identical. Same kube-state-metrics version, same flags, same metrics output, same nonroot UID
  65532

FIPS variants are appropriate for regulated environments such as FedRAMP, government, healthcare, financial services,
and defense deployments.

# Migrate to a Docker Hardened Image

To migrate your kube-state-metrics deployment to a Docker Hardened Image, update the image reference in your Helm
values, Dockerfile, or Kubernetes manifests. The following table lists the most common changes:

| Item               | Migration note                                                                                                                                                                                                                         |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base image with `dhi.io/kube-state-metrics:<tag>`. Note tags use no `v` prefix.                                                                                                                                           |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                            |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (UID 65532). Pod security contexts in your manifests should not assume a different UID.                                                                      |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                     |
| Ports              | The image exposes ports 8080 (metrics) and 8081 (telemetry). Both are above 1024 and unaffected by the privileged-port restriction for nonroot containers.                                                                             |
| Entry point        | The entrypoint is `kube-state-metrics` with default flags `--port=8080 --telemetry-port=8081`. To run other subcommands such as `version`, override the entrypoint with `--entrypoint kube-state-metrics` to clear the baked-in flags. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use `dev` images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                          |
| Image pull secret  | For Kubernetes deployments, create a pull secret for `dhi.io` and reference it in `imagePullSecrets`. The upstream Helm chart accepts this via `--set "imagePullSecrets[0].name=..."`.                                                 |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. **Install additional packages.**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. Only images tagged
   as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the packages. Install
   the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary artifacts to the runtime
   stage that uses a non-dev image.

   For Debian-based images, you can use `apt-get` to install packages.

# Troubleshoot migration

The following are common issues that you may encounter during migration.

## General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

For kube-state-metrics specifically, the most common operational issues are RBAC and authentication errors visible in
the pod's stdout logs. Use `kubectl logs <pod>` to inspect them. The `/metrics` endpoint on port 8081 also exposes
telemetry about the exporter itself, which is useful for diagnosing scrape failures and resource pressure.

## Permissions

By default image variants intended for runtime, run as the nonroot user (UID 65532). The kube-state-metrics binary does
not write to disk and does not require host filesystem mounts, so permission issues are typically RBAC-related rather
than UID-related: the pod's ServiceAccount must have `list` and `watch` permissions on the resource types being exposed.
The upstream Helm chart configures this RBAC automatically.

## Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The default
kube-state-metrics ports (8080 and 8081) are above 1024 and are unaffected. If you override `--port` or
`--telemetry-port`, use values above 1024.

## No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

## Entry point

The hardened image's entrypoint is `kube-state-metrics --port=8080 --telemetry-port=8081`. The `--port` and
`--telemetry-port` flags are baked into the entrypoint and apply only to the metrics server, not to subcommands such as
`version` or `help`. To run a subcommand, override the entrypoint:

```bash
$ docker run --rm --entrypoint kube-state-metrics dhi.io/kube-state-metrics:<tag> version
$ docker run --rm --entrypoint kube-state-metrics dhi.io/kube-state-metrics:<tag> help
```

Use `docker inspect` to view the exact entrypoint and command for a specific tag.
