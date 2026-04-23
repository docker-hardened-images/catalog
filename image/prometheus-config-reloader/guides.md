## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Prometheus Config Reloader Hardened image

Prometheus Config Reloader is a lightweight sidecar utility from the Prometheus Operator project that watches a
configuration file (and optional directories) for changes, then triggers a reload on the target process. It is typically
deployed alongside Prometheus or Alertmanager to pick up updated ConfigMaps in Kubernetes without restarting the main
container.

This Docker Hardened Prometheus Config Reloader image includes:

- `prometheus-config-reloader` (the reloader binary, set as the image entrypoint)

The image supports two reload methods: an HTTP POST to a configurable URL (the default, used by Prometheus and
Alertmanager), or sending a SIGHUP to a named process. It does not expose any ports or require a default configuration —
all behavior is controlled by command-line flags.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

# Start a Prometheus Config Reloader instance

Run the following command to see the binary's flags and defaults:

```bash
$ docker run --rm dhi.io/prometheus-config-reloader:<tag> --help
```

Use `--version` to print the binary version:

```bash
$ docker run --rm dhi.io/prometheus-config-reloader:<tag> --version
```

To run the reloader against a config file, mount the file into the container and pass `--config-file` and
`--reload-url`:

```bash
$ docker run -d --name config-reloader \
  -v /path/to/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  dhi.io/prometheus-config-reloader:<tag> \
  --config-file=/etc/prometheus/prometheus.yml \
  --reload-url=http://prometheus:9090/-/reload
```

The hostname in `--reload-url` must resolve on the network where the container runs. In the example above, `prometheus`
should be a container name or service name reachable on a shared Docker network (for example, via
`docker network create` and `--network`, or as a service in Docker Compose or Kubernetes). If the target is not
reachable, the reloader logs a DNS or connection error and retries on the next tick; it does not exit.

The reloader watches the config file and any directories passed with `--watched-dir` (may be repeated). When it detects
a change, it waits `--delay-interval` (default 1s) and then issues the configured reload. The full watch cycle runs
every `--watch-interval` (default 3m0s).

# Common Prometheus Config Reloader use cases

## Reload Prometheus on config change

The defaults of `prometheus-config-reloader` target a Prometheus instance on `localhost:9090`. When Prometheus and the
reloader share a network namespace (for example, running both in the same Docker network with aliases, or as sidecar
containers in a single pod), the reloader POSTs to `http://127.0.0.1:9090/-/reload` on any detected change without any
`--reload-url` override.

Prometheus must be started with `--web.enable-lifecycle` for the `/-/reload` endpoint to accept POST requests. Without
this flag, the reloader receives `404 Not Found` and retries on the next tick.

## Reload Alertmanager on config change

To use the reloader with Alertmanager, override `--reload-url` to point at the Alertmanager reload endpoint:

```bash
$ docker run -d --name alertmanager-reloader \
  -v /path/to/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro \
  dhi.io/prometheus-config-reloader:<tag> \
  --config-file=/etc/alertmanager/alertmanager.yml \
  --reload-url=http://alertmanager:9093/-/reload
```

## Reload via signal instead of HTTP

When the target process's HTTP reload endpoint is disabled (for example, a Prometheus started without
`--web.enable-lifecycle`), use `--reload-method=signal`. The reloader sends SIGHUP to a process named in
`--process-executable-name`:

```bash
$ docker run -d --name config-reloader \
  --pid=container:<target-container> \
  --network=container:<target-container> \
  --user 65532:65532 \
  -v /path/to/config.yml:/etc/prometheus/prometheus.yml:ro \
  dhi.io/prometheus-config-reloader:<tag> \
  --config-file=/etc/prometheus/prometheus.yml \
  --reload-method=signal \
  --process-executable-name=prometheus
```

Signal reload has three strict requirements that differ from HTTP reload:

- **Shared PID namespace** (`--pid=container:...` in Docker, automatic for containers in the same Kubernetes pod).
  Without it, the reloader can't see the target process to signal it.
- **Shared network namespace** (`--network=container:...` in Docker, also automatic in a Kubernetes pod). Signal mode
  still performs an HTTP pre-reload check against `--runtimeinfo-url` (default
  `http://127.0.0.1:9090/api/v1/status/runtimeinfo`) and a post-reload confirmation, so the target's HTTP port must be
  reachable.
- **Matching UIDs.** The reloader runs as UID 65532 and can only signal processes owned by the same UID. If the target
  runs as a different non-root user (for example, upstream Prometheus defaults to UID 65534), the reloader gets
  `failed to send SIGHUP to pid N: operation not permitted`. Run the target with `--user 65532:65532` or configure a
  matching `securityContext.runAsUser: 65532` in Kubernetes.

## Use with the Prometheus Operator

The Prometheus Operator deploys `prometheus-config-reloader` as a sidecar automatically in the pods it manages. To tell
the operator to use a specific reloader image (for example, the Docker Hardened Image), pass
`--prometheus-config-reloader` to the operator at startup:

```
--prometheus-config-reloader=dhi.io/prometheus-config-reloader:<tag>
```

The operator then references this image in the `Prometheus` and `Alertmanager` CRD pod specs it creates. This flag only
takes effect when the operator runs inside a Kubernetes cluster with access to the API server — it cannot be tested
standalone with `docker run`.

## Enable metrics

The reloader's own metrics endpoint is disabled by default. To enable it, set `--listen-address`:

```bash
$ docker run -d --name config-reloader -p 8080:8080 \
  -v /path/to/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  dhi.io/prometheus-config-reloader:<tag> \
  --config-file=/etc/prometheus/prometheus.yml \
  --reload-url=http://prometheus:9090/-/reload \
  --listen-address=:8080
```

Reloader metrics are then available at `http://localhost:8080/metrics` in Prometheus exposition format. Key counters
include:

- `reloader_config_apply_operations_total` — number of config-apply cycles triggered by detected file changes (not
  individual HTTP POST attempts)
- `reloader_config_apply_operations_failed_total` — apply cycles that exhausted all retries without success
- `prometheus_config_reloader_build_info` — gauge labeled with the reloader's version, revision, branch, and Go version
  for fleet inventory

# Non-hardened images vs Docker Hardened Images

## Key differences

| Feature         | Docker Official Prometheus Config Reloader | Docker Hardened Prometheus Config Reloader          |
| --------------- | ------------------------------------------ | --------------------------------------------------- |
| Security        | Standard base with common utilities        | Minimal, hardened Debian 13 base                    |
| Shell access    | Full shell available                       | No shell in runtime variants                        |
| Package manager | `apk`/`apt` available                      | No package manager in runtime variants              |
| User            | Runs as root by default                    | Runs as nonroot user (UID 65532)                    |
| Attack surface  | Larger due to additional utilities         | Minimal — binary only, no other tools               |
| Debugging       | Traditional shell debugging                | Use Docker Debug or Image Mount for troubleshooting |
| Compliance      | None                                       | CIS                                                 |
| Attestations    | None                                       | SBOM, provenance, VEX metadata                      |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened image contains only the `prometheus-config-reloader` binary and its required libraries — no shell, no
coreutils, no package manager, no editors. Common debugging methods for applications built with Docker Hardened Images
include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session. For example:

```bash
$ docker debug config-reloader
```

Or mount debugging tools with the Image Mount feature:

```bash
$ docker run --rm -it --pid container:config-reloader \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/prometheus-config-reloader:<tag>
```

For operational visibility without attaching a debugger, enable the reloader's metrics endpoint with `--listen-address`
(see [Enable metrics](#enable-metrics)).

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
- Include a shell and package manager
- Are used to build or compile applications

The Prometheus Config Reloader image is published as a runtime variant only. Because the binary is a statically-linked
Go executable that requires no build-time dependencies, no `dev` variant is published for this image. Available tags
follow the pattern `<version>` or `<version>-debian13`, for example `0.86` or `0.86-debian13`.

To view all published tags and get more information about each variant, select the Tags tab for this repository.

# Migrate to a Docker Hardened Image

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
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. The entry point for this image is `/usr/local/bin/prometheus-config-reloader` with no default CMD — you must pass flags explicitly.                                                                                       |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use `dev` images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                |

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

For the reloader specifically, most operational debugging can be done through logs and the optional metrics endpoint.
Use `--log-level=debug` for verbose reload activity, and enable `--listen-address=:8080` to expose reload counters at
`/metrics`.

## Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

The reloader reads the file passed to `--config-file` and any directories passed to `--watched-dir`. These must be
readable by UID 65532. If `--config-envsubst-file` is set, the output path must be writable by the same UID.

## Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The reloader
does not listen on any ports by default. When `--listen-address` is set for metrics, use a port above 1024, for example
`:8080`.

## No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

## Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
