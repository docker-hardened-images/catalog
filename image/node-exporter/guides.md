## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Image-specific usage notes

node_exporter is a Prometheus exporter that exposes a wide range of hardware- and OS-level metrics for \*NIX systems.
It's typically deployed as a DaemonSet in Kubernetes (one pod per node) or as a host-level process or container on
bare-metal Linux servers, and scraped by Prometheus on port 9100.

This Docker Hardened image ships the production `node_exporter` binary as the container entrypoint. The image is
configured entirely via command-line flags — no environment variables or configuration files are required. TCP port 9100
is exposed by default for metrics scraping.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

# Start a node-exporter instance

Run node-exporter with its default flags and publish port 9100 so Prometheus (or any client) can scrape it:

```bash
$ docker run -d --name node-exporter -p 9100:9100 \
  dhi.io/node-exporter:<tag>
```

Verify it's serving metrics:

```bash
$ curl http://localhost:9100/metrics | head -5
```

This runs node-exporter with the default set of enabled collectors, inspecting the container's own cgroup and namespace
view. To gather metrics about the underlying host instead, see [Monitor the host](#monitor-the-host) below.

# Common node-exporter use cases

## Monitor the host

To collect host-level metrics, node_exporter must access host namespaces and the host filesystem. On bare-metal Linux,
run the container with host networking, host PID namespace, and a bind mount of the host root filesystem:

```bash
$ docker run -d --name node-exporter \
  --net=host --pid=host \
  -v "/:/host:ro,rslave" \
  dhi.io/node-exporter:<tag> \
  --path.rootfs=/host
```

Once running, Prometheus (or any scrape client) can reach the exporter at `http://<host>:9100/metrics`. The
`--path.rootfs=/host` flag tells node-exporter where the host filesystem is mounted inside the container so it can
report correct paths and device names.

> **Docker Desktop note.** The command above is written for bare-metal Linux. On Docker Desktop for Mac and Windows it
> has two known differences:
>
> - The `rslave` mount propagation flag fails with `path / is mounted on / but it is not a shared or slave mount`. Drop
>   `rslave` and use `-v "/:/host:ro"` instead.
> - `--net=host` binds to the Docker Desktop Linux VM's network, not the host OS. Metrics are unreachable from
>   `curl localhost:9100` on the Mac/Windows host; they can only be reached from inside another container on the same
>   host network.
> - "Host" metrics describe the Docker Desktop Linux VM (filesystems like `/dev/vda1` and `/run/host_virtiofs/*`), not
>   the Mac or Windows host. For monitoring Docker Desktop development environments, this is often still useful, but it
>   is not equivalent to bare-metal host monitoring.

## Run containerized without host access

If you only need the exporter to expose metrics for the container itself (for example, to verify the image, run it in
CI, or scrape the runtime environment), run it with a simple port mapping and no host mounts:

```bash
$ docker run -d --name node-exporter -p 9100:9100 \
  dhi.io/node-exporter:<tag>
```

This is the safest configuration when you do not have permission to expose host namespaces to the container.

## Run with Docker Compose

```yaml
services:
  node-exporter:
    image: dhi.io/node-exporter:<tag>
    container_name: node-exporter
    network_mode: host
    pid: host
    restart: unless-stopped
    volumes:
      - '/:/host:ro'
    command:
      - '--path.rootfs=/host'
```

As with the `docker run` host-monitoring example, this is written for bare-metal Linux. On Docker Desktop drop any
`rslave` propagation flag; with the form shown above the service will start correctly.

## Deploy as a Kubernetes DaemonSet

Deploy node-exporter as a DaemonSet so Kubernetes schedules one pod per node. Each pod uses `hostNetwork`, `hostPID`,
and a `hostPath` volume mounted at `/host` to read from the node's root filesystem. The `imagePullSecrets` field
references a pull secret you must create first for `dhi.io` — see
[DHI authentication in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/).

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
spec:
  selector:
    matchLabels:
      name: node-exporter
  template:
    metadata:
      labels:
        name: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      imagePullSecrets:
        - name: helm-pull-secret
      containers:
        - name: node-exporter
          image: dhi.io/node-exporter:<tag>
          args:
            - "--path.rootfs=/host"
          ports:
            - name: metrics
              containerPort: 9100
              hostPort: 9100
          volumeMounts:
            - name: host-root
              mountPath: /host
              readOnly: true
      volumes:
        - name: host-root
          hostPath:
            path: /
```

With this DaemonSet applied to a cluster, Prometheus can scrape each node at `http://<node-ip>:9100/metrics`. Emitted
metrics describe each Kubernetes node (`node_uname_info{nodename="…"}`, filesystem and disk stats per node, per-CPU
usage, etc.), which is the standard host-monitoring pattern for Kubernetes.

## Configure custom flags

node_exporter has many runtime flags. Common ones:

| Flag                                           | Description                                        | Default    |
| ---------------------------------------------- | -------------------------------------------------- | ---------- |
| `--web.listen-address`                         | Address and port to listen on for metrics          | `:9100`    |
| `--path.rootfs`                                | Prefix for host filesystem paths when bind-mounted | (empty)    |
| `--collector.<name>` / `--no-collector.<name>` | Enable or disable individual collectors            | varies     |
| `--web.telemetry-path`                         | URL path for the metrics endpoint                  | `/metrics` |

Example: run with a custom listen port, disable the filesystem collector, and serve metrics at a non-default path:

```bash
$ docker run -d --name node-exporter -p 9180:9180 \
  dhi.io/node-exporter:<tag> \
  --web.listen-address=":9180" \
  --no-collector.filesystem \
  --web.telemetry-path=/node-metrics
```

For the full list of flags and collectors, run the image with `--help`:

```bash
$ docker run --rm dhi.io/node-exporter:<tag> --help
```

## Prometheus scrape configuration

Add node-exporter as a scrape target in your Prometheus config:

```yaml
scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['<node-hostname-or-ip>:9100']
```

For Kubernetes deployments, the upstream Prometheus community Helm charts and the `ServiceMonitor` pattern via the
Prometheus Operator both handle DaemonSet-based node-exporter scraping automatically.

# Non-hardened images vs Docker Hardened Images

## Key differences

| Feature         | Docker Official node-exporter       | Docker Hardened node-exporter                       |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened Debian 13 base                    |
| Shell access    | Full shell available                | No shell in runtime variants                        |
| Package manager | `apk` / `apt` available             | No package manager in runtime variants              |
| User            | Runs as nobody (UID 65534) or root  | Runs as nonroot user (UID 65532)                    |
| Attack surface  | Larger due to additional utilities  | Minimal — binary only, no other tools               |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| Compliance      | None                                | CIS; FIPS 140-3 and STIG in FIPS variants           |
| Attestations    | None                                | SBOM, provenance, VEX metadata                      |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened image contains only the `node_exporter` binary and its required libraries — no shell, no coreutils, no
package manager, no editors. Common debugging methods for applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session. For example:

```bash
$ docker debug node-exporter
```

Or mount debugging tools with the Image Mount feature:

```bash
$ docker run --rm -it --pid container:node-exporter \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/node-exporter:<tag>
```

For operational visibility without attaching a debugger, the `/metrics` endpoint itself exposes Go runtime metrics
(`go_*`), process metrics (`process_*`), and node-exporter's own scrape metrics (`node_scrape_collector_*`).

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (UID 65532)
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants include `dev` in the variant name and are intended for use in the first stage of a multi-stage
Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications, or to install additional binaries alongside node-exporter

The node-exporter image is published in the following variant combinations:

| Variant           | Tag pattern                                         | User    | Compliance      | Availability      |
| ----------------- | --------------------------------------------------- | ------- | --------------- | ----------------- |
| Runtime           | `<version>`, `<version>-debian13`                   | nonroot | CIS             | Public            |
| Build-time (dev)  | `<version>-dev`, `<version>-debian13-dev`           | root    | CIS             | Public            |
| Runtime + FIPS    | `<version>-fips`, `<version>-debian13-fips`         | nonroot | CIS, FIPS, STIG | Subscription only |
| Build-time + FIPS | `<version>-fips-dev`, `<version>-debian13-fips-dev` | root    | CIS, FIPS, STIG | Subscription only |

Alpine 3.23 variants are also published with tag patterns `<version>-alpine3.23`, `<version>-alpine3.23-fips`, etc.

To view all published tags and get more information about each variant, select the Tags tab for this repository.

# FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

The node-exporter FIPS variants are available through DHI Select and DHI Enterprise subscriptions only. To use them,
mirror the repository into your own namespace and pull from your mirror. See
[Mirror a DHI repository](https://docs.docker.com/dhi/how-to/mirror/).

FIPS variants of the node-exporter image are drop-in replacements for the standard runtime variant — same entrypoint,
same port, same nonroot UID 65532. node_exporter does not require any FIPS-specific configuration flags. All TLS
operations (if enabled via `--web.tls-cert-file` and `--web.tls-key-file`) automatically use the FIPS-validated
cryptographic providers.

## Verify the FIPS attestation

FIPS variants include a signed FIPS attestation listing the cryptographic modules in the image and their validation
status. Retrieve it with Docker Scout against your mirrored repository:

```bash
$ docker scout attest get \
    --predicate-type https://docker.com/dhi/fips/v0.1 \
    --predicate \
    <your-namespace>/dhi-node-exporter:<version>-fips
```

## What changes in FIPS mode

Compared to the standard runtime variant:

- **Cryptographic modules**: OpenSSL FIPS Provider is used for TLS operations
- **Available algorithms**: only FIPS 140-approved algorithms are available
- **Image size**: slightly larger due to the FIPS provider module
- **Compliance labels**: carries `com.docker.dhi.compliance=fips,stig,cis`
- **Everything else**: identical. Same node_exporter version, same flags, same metrics output

FIPS variants are appropriate for regulated environments such as FedRAMP, government, healthcare, financial services,
and defense deployments.

# Migrate to a Docker Hardened Image

To migrate your node-exporter deployment to a Docker Hardened Image, update the image reference in your Dockerfile,
Compose file, or Kubernetes manifests. The following table lists the most common changes:

| Item               | Migration note                                                                                                                                                                                                                                                 |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base image with `dhi.io/node-exporter:<tag>`.                                                                                                                                                                                                     |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                    |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (UID 65532). Ensure that any bind-mounted paths the exporter reads are accessible.                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                                               |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                             |
| Ports              | Non-dev hardened images run as a nonroot user by default. node_exporter's default port 9100 is above 1024 and is unaffected. Custom `--web.listen-address` values should also use ports above 1024.                                                            |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. The entry point for this image is `node_exporter` (on PATH) with no default CMD — pass flags as arguments to `docker run` or in your `args:` in Kubernetes. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use `dev` images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                  |
| Image pull secret  | For Kubernetes deployments, create a pull secret for `dhi.io` and reference it in the pod spec's `imagePullSecrets`. DHI images require authentication for cluster pulls.                                                                                      |

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

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

# Troubleshoot migration

The following are common issues that you may encounter during migration.

## General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

For node-exporter specifically, most operational troubleshooting can be done through the exporter's own output:

- Scrape `http://<host>:9100/metrics` and inspect the `node_scrape_collector_*` metrics for per-collector scrape
  duration and success counts
- Use `--log.level=debug` for verbose collector activity
- Check the container's stdout logs for collector initialization messages and any disabled-collector warnings

## Permissions

By default image variants intended for runtime, run as the nonroot user (UID 65532). Ensure that necessary files and
directories are accessible to the nonroot user.

For host monitoring, the bind-mounted root filesystem is typically mounted read-only (`/:/host:ro`), so UID permissions
on the host don't need to match. However, some collectors read from paths that require additional privileges or
capabilities:

- The `timex` collector may require `--cap-add=SYS_TIME` on certain hosts
- Some cgroup and process collectors behave differently without `--pid=host`
- The `diskstats` collector may log warnings about `/run/udev/data` on systems where udev isn't accessible; the
  collector continues to work with reduced device metadata

## Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. node_exporter's
default port 9100 is above 1024 and is unaffected. If you configure a custom `--web.listen-address`, use a port above
1024\.

## No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

## Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
