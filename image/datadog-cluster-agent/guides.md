## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/datadog-cluster-agent:<tag>`
- Mirrored image: `<your-namespace>/dhi-datadog-cluster-agent:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this datadog-cluster-agent image

This Docker Hardened `datadog-cluster-agent` image includes:

- `datadog-cluster-agent` -- the Cluster Agent binary, available at `/opt/datadog-agent/bin/datadog-cluster-agent` (also
  reachable as `/opt/datadog-agent/bin/agent` and on `PATH`).
- `cws-instrumentation` -- the Cloud Workload Security instrumentation helper used when the Cluster Agent injects CWS
  into target workloads via an admission controller mutation.
- `secret-generic-connector` -- a generic Datadog secret-backend connector that can be referenced from
  `secret_backend_command` to resolve `ENC[...]` references at runtime.
- `nosys.so` -- a small libseccomp shim that the Cluster Agent loads through `LD_PRELOAD`. It returns `ENOSYS` for newer
  syscalls that older kernels don't support so the agent doesn't crash on them.
- The `/etc/datadog-agent/` configuration tree (`datadog-cluster.yaml`, `conf.d/`, `install_info`, and
  `private-action-runner/script-config.yaml`).

## Start a datadog-cluster-agent container

The Cluster Agent always needs a Datadog API key. Set one via the `DD_API_KEY` environment variable. Verify the image
starts and prints its version:

```bash
$ docker run --rm \
  -e DD_API_KEY=<your-api-key> \
  dhi.io/datadog-cluster-agent:<tag> version
```

You can also list available subcommands:

```bash
$ docker run --rm \
  -e DD_API_KEY=<your-api-key> \
  dhi.io/datadog-cluster-agent:<tag> --help
```

## Common datadog-cluster-agent use cases

### Deploy on Kubernetes with Helm (recommended)

The Cluster Agent is designed to run inside a Kubernetes cluster alongside the Datadog node Agent. The supported
deployment path is the official `datadog/datadog` Helm chart, which provisions both agents, RBAC, and the cluster
service used by node agents to reach the Cluster Agent.

```bash
$ helm repo add datadog https://helm.datadoghq.com
$ helm install datadog datadog/datadog \
  --set datadog.apiKey=<your-api-key> \
  --set clusterAgent.enabled=true \
  --set clusterAgent.image.repository=dhi.io/datadog-cluster-agent \
  --set clusterAgent.image.tag=<tag>
```

See the [upstream Cluster Agent setup guide](https://docs.datadoghq.com/agent/cluster_agent/setup/) for chart values
covering external metrics, cluster checks, admission controller, and orchestrator explorer.

### Run as a standalone container (testing only)

The Cluster Agent will start and serve its command API on port `5005`, but it is only useful when paired with a
Kubernetes cluster it can reach. This pattern is mainly helpful for verifying the image runs:

```bash
$ docker run --rm \
  -e DD_API_KEY=<your-api-key> \
  -e DD_CLUSTER_AGENT_AUTH_TOKEN=<token> \
  -p 5005:5005 \
  dhi.io/datadog-cluster-agent:<tag>
```

### Resolve `ENC[...]` secrets via the bundled connector

The image ships `secret-generic-connector` at `/opt/datadog-agent/bin/secret-generic-connector`. Wire it up by setting
`secret_backend_command` in your `datadog-cluster.yaml` (or via the equivalent Helm value):

```yaml
secret_backend_command: /opt/datadog-agent/bin/secret-generic-connector
```

## Non-hardened images vs. Docker Hardened Images

The Cluster Agent's hardened image runs as the `nonroot` user (uid `65532`) by default. The upstream image runs as root.

Practical consequence: avoid binding to privileged ports (`<1024`). The binary's own default for
`external_metrics_provider.port` is `8443`, and the upstream Helm chart matches that
(`clusterAgent.metricsProvider.service.port`, propagated to `DD_EXTERNAL_METRICS_PROVIDER_PORT`). The only failure case
is an explicit override to a privileged port such as `443`; in that case, set the env var so the binary listens on a
non-privileged port:

```yaml
- name: DD_EXTERNAL_METRICS_PROVIDER_PORT
  value: "8443"
```

The hardened image also omits the `/entrypoint.sh` wrapper from upstream -- the cluster-agent binary is the entry point
directly. `DD_API_KEY` is still required and is validated by the binary itself.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. The Cluster Agent runs with `GODEBUG=fips140=on` (lenient mode) so that TLS 1.3 traffic to
  the Kubernetes API server (which negotiates X25519 via `client-go`) continues to work.

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
