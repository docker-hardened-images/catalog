## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/datadog-agent:<tag>`
- Mirrored image: `<your-namespace>/dhi-datadog-agent:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Datadog Agent image

This Docker Hardened Datadog Agent image includes:

- `agent` - the core Datadog Agent for metric collection and orchestration
- `trace-agent` - APM trace collection and forwarding
- `process-agent` - the standalone process agent. It ships for parity with the upstream image, but the core agent runs
  the process checks (see below), so the standalone binary does not stay up
- `security-agent` - Cloud Security Management agent
- The Python integration checks (the `datadog_checks` payload: postgres, redis, kafka, mysql, sqlserver, mongo, and the
  rest of the standard set), for the embedded interpreter
- JMX integration support (JMXFetch on a bundled JRE) for checks such as cassandra, tomcat, kafka, solr, and activemq
- The SQL Server (FreeTDS plus the Microsoft ODBC driver) and IBM MQ client libraries the corresponding checks require.
  The Microsoft ODBC driver and the IBM MQ client are proprietary, redistributable drivers shipped unmodified; their
  license texts ship alongside them, at `/usr/share/doc/msodbcsql18/LICENSE.txt` and `/opt/mqm/licenses` respectively.
  The IBM MQ client is amd64 only; no arm64 redistributable exists, so the `ibm_mq` check is unavailable on arm64 images
- `secret-generic-connector` - a generic Datadog secret-backend connector that resolves `ENC[...]` secrets, at
  `/opt/datadog-agent/embedded/bin/secret-generic-connector`

## Start a Datadog Agent container

### Check the version and available commands

The `version` and `help` subcommands run without an API key. Print the agent version:

```bash
$ docker run --rm dhi.io/datadog-agent:<tag> version
```

List the available subcommands:

```bash
$ docker run --rm dhi.io/datadog-agent:<tag> help
```

### Basic usage

```bash
$ docker run -d --name dd-agent \
  -e DD_API_KEY=<your-api-key> \
  -e DD_SITE=datadoghq.com \
  -e DD_HOSTNAME=<a-hostname-for-this-container> \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /proc/:/host/proc/:ro \
  -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
  dhi.io/datadog-agent:<tag>
```

`DD_HOSTNAME` is required outside a cloud provider: the agent's own hostname detection depends on cloud-provider
metadata endpoints or a working reverse-DNS lookup, neither of which exist on a bare Docker host, and the agent exits
instead of starting with no hostname resolved.

This image runs as a non-root user, unlike upstream's own `datadog/agent` image. A plain bind mount of
`/var/run/docker.sock` is usually owner `root:root` mode `0660` on the host, which the agent's user cannot read, so
Docker container monitoring and log tailing silently turn off (the agent logs `Docker log tailing disabled` /
`socket not reachable`, but still starts). Add the container's user to a group matching the socket's host GID to fix
this, for example `--group-add $(stat -c '%g' /var/run/docker.sock)`.

### With Docker Compose

```yaml
services:
  datadog-agent:
    image: dhi.io/datadog-agent:<tag>
    container_name: dd-agent
    environment:
      - DD_API_KEY=<your-api-key>
      - DD_SITE=datadoghq.com
      - DD_HOSTNAME=<a-hostname-for-this-container>
      - DD_LOGS_ENABLED=true
      - DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc/:/host/proc/:ro
      - /sys/fs/cgroup/:/host/sys/fs/cgroup:ro
    ports:
      - "8125:8125/udp"
```

DogStatsD binds loopback-only by default, so the `8125:8125/udp` publish above has no effect unless
`DD_DOGSTATSD_NON_LOCAL_TRAFFIC` is also set, which tells the agent to bind all interfaces instead. Nothing listens on
port 8126 in this container, because the default command runs only the core agent. For APM, run `trace-agent` as its own
container (see the comparison section below) and publish `8126/tcp` there.

### Environment variables

| Variable          | Description                  | Default         | Required                      |
| :---------------- | :--------------------------- | :-------------- | :---------------------------- |
| `DD_API_KEY`      | Your Datadog API key         | None            | Yes                           |
| `DD_SITE`         | Datadog intake site          | `datadoghq.com` | No                            |
| `DD_HOSTNAME`     | Hostname reported to Datadog | None            | Yes, outside a cloud provider |
| `DD_LOGS_ENABLED` | Enable log collection        | `false`         | No                            |

This image does not ship a default `datadog.yaml`; configuration is supplied through `DD_*` environment variables (as
shown above) or by mounting your own file at `/etc/datadog-agent/datadog.yaml`.

Integration and Autodiscovery configuration files go in `/etc/datadog-agent/conf.d/`, for example
`-v <PATH>/postgres.d:/etc/datadog-agent/conf.d/postgres.d:ro`. The `/conf.d` mount that the upstream image reads is not
supported, because this image has no start-up scripts to copy it. A file mounted there is ignored without an error.

For the full list of configuration options, see the
[Datadog Agent documentation](https://docs.datadoghq.com/agent/configuration/).

### Resolve `ENC[...]` secrets via the bundled connector

The agent reads the secret settings only when a `datadog.yaml` file exists. With no file mounted, the
`DD_SECRET_BACKEND_*` variables have no effect, and an `ENC[...]` value is used as written, with no error. Mount a
`datadog.yaml` file, even one with a single setting, to use secrets.

Setting `secret_backend_type` (or `DD_SECRET_BACKEND_TYPE`) in your `datadog.yaml` to a supported backend wires up
`secret-generic-connector` automatically, with no extra configuration needed. To call it explicitly instead, set
`secret_backend_command` (or `DD_SECRET_BACKEND_COMMAND`):

```yaml
secret_backend_command: /opt/datadog-agent/embedded/bin/secret-generic-connector
```

The connector runs with restrictive permissions (owned `root:secret-manager`, mode `0550`), matching upstream's own
requirement that a secret backend executable not be writable or executable by anyone other than the agent.

### Deploy on Kubernetes

The official `datadog/datadog` Helm chart is built for the upstream `datadog/agent` image, and it is not a drop-in for
this image. With the chart's default settings these things fail against this image:

- The chart starts `trace-agent` through `trace-loader` (chart tags 7.75.0 and later), and starts `system-probe` for
  discovery (7.78.0 and later). This image ships neither binary.
- The chart's `init-config` container runs the scripts in `/etc/cont-init.d` to write `datadog.yaml`, to copy the files
  from `datadog.confd` and `datadog.checksd`, and to set up the platform links. This image has no such scripts. The
  `config` volume stays without a `datadog.yaml`, and `trace-agent` exits with `Config File Not Found`.
- The chart's init containers also run a shell, which the runtime image does not have.

To run this image on Kubernetes, write the manifests yourself and use one container per component, all in the same pod.
Run `agent run` for the core agent, and give each other agent its own container with its own command (see the comparison
section below). The trace and security agents call the core agent over its IPC endpoint, so they need the shared token
described below. Create `datadog.yaml` from a `ConfigMap` or a `Secret` and mount it at
`/etc/datadog-agent/datadog.yaml`.

## Non-hardened images vs. Docker Hardened Images

The hardened Datadog Agent image differs from the upstream `datadog/agent` image in the following ways:

| Feature                        | Upstream | Hardened                       |
| :----------------------------- | :------- | :----------------------------- |
| Default user                   | root     | dd-agent (uid 100)             |
| s6-overlay process supervisor  | Included | Not included                   |
| Shell                          | Included | Not included (use dev variant) |
| Package manager                | Included | Not included (use dev variant) |
| System probe (eBPF)            | Included | Not included                   |
| Start-up scripts (`cont-init`) | Included | Not included                   |
| Helm chart as a drop-in        | Yes      | No                             |
| Container health check         | Set      | Not set                        |

The agent must run as uid 100. The directories it writes to (`/etc/datadog-agent`, `/var/log/datadog`, `/run/datadog`
and `/opt/datadog-agent/run`) belong to `dd-agent` with mode `0770`. Upstream's image puts its user in the root group
and gives that group write access, so it also runs with an arbitrary uid. This image does not. With another uid the
agent cannot write its log file, and after about 30 seconds it exits with
`failed to acquire lock for auth_token: open auth_token.lock: permission denied`. In Kubernetes, set `runAsUser: 100`.
On OpenShift, the `restricted` security context constraint assigns a uid from the namespace range, so it may reject
`runAsUser: 100` unless the service account can use a constraint that allows it. This was not tested on OpenShift.

The hardened image sets no container `HEALTHCHECK`. Upstream's image runs `agent health` as its health check. To get the
same check, call `/opt/datadog-agent/bin/agent/agent health` from a Kubernetes exec probe or a Compose `healthcheck`
while the agent runs.

The hardened image runs the agent binaries directly without the s6-overlay process supervisor, and without the start-up
scripts of the upstream image: it does not create a default `datadog.yaml`, check `DD_API_KEY`, copy a `/conf.d` mount,
or set up the Kubernetes and ECS integrations. It also does not ship `trace-loader` or `system-probe`. The
`agent integration` command is present but fails, because the file `requirements-agent-release.txt` is not in the image,
so community integrations cannot be added with `agent integration install`. The default entrypoint runs only the core
`agent` binary (`agent run`); it does not start the trace, process, or security agents as child processes. To run the
trace or security agent, start each as its own container from the same image with its own command, in the same pod (or
the same network namespace) as the core agent. This is the model the Datadog Helm chart and Operator use. These agents
call the core agent over its IPC endpoint and must trust its token. Mount one shared volume in every container and set
`DD_AUTH_TOKEN_FILE_PATH` to a file on that volume in every container. The volume must be writable by uid 100, the user
of this image. In Kubernetes, an `emptyDir` volume is. With Docker, a named volume mounted over `/opt/datadog-agent/run`
works, because the image creates that directory for uid 100. Without a shared token, they retry the connection without
end or fail with an `x509` certificate error, and the trace agent loses tagging and remote configuration. These agents
also get their configuration from the core agent as a stream, and they wait for it before they start, so with no
reachable core agent they print nothing and do not start. The core agent is the source of their configuration: set
`DD_*` environment variables on the core agent container, because a remote agent ignores its own. To run one alone, set
`DD_REMOTE_AGENT_CONFIGSTREAM_CONSUMER_ENABLED=false` in its container. Each of these binaries reads its configuration
from `/etc/datadog-agent/datadog.yaml`, which this image does not ship by default (see above), so mount a real file at
that path rather than relying on `DD_*` environment variables alone:

- trace-agent, entrypoint `/opt/datadog-agent/embedded/bin/trace-agent`, command `run`
- process-agent, entrypoint `/opt/datadog-agent/embedded/bin/process-agent`, no command (the binary itself is the
  daemon; it has no `run` subcommand). On Linux in this release, the core agent runs the process checks, so a separate
  process-agent container exits right away with the message `process-agent is not enabled, exiting`. Do not run it as
  its own container. Use the default `agent run` container for live process and container monitoring.
- security-agent, entrypoint `/opt/datadog-agent/embedded/bin/security-agent`, command `start`

The security agent exits right away unless its configuration sets a `hostname` (or it can reach a core agent that
resolves one) and turns on at least one of its features, for example `compliance_config.enabled: true`. The runtime
security feature needs the system probe, which this image does not include.

In the FIPS variants, the Go binaries use Go's FIPS 140 module, and the Python checks use the system OpenSSL FIPS
provider for TLS and for `hashlib` and `cryptography`. Some Python packages bring their own crypto code, for example
PyNaCl (libsodium) and the pure-Python MD4 in `pyspnego`. Those code paths do not go through the OpenSSL provider. The
JMXFetch process runs on a JRE with the BCFIPS provider, set through `JAVA_TOOL_OPTIONS`. If you set the agent option
`jmx_java_tool_options`, it replaces that variable for JMXFetch, so include the image's value in yours. The `FIPS Mode`
line in `agent status` reads `not available` because upstream only reports it for its own FIPS flavor, built with the
`systemcrypto` Go experiment. It does not show whether the validated module is in use.

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
