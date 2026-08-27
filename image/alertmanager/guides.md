## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

# Start an Alertmanager instance

The Docker Hardened Alertmanager image includes a default configuration file and ships with sensible default CMD flags
(`--config.file=/etc/alertmanager/alertmanager.yml --storage.path=/alertmanager`), so you can start Alertmanager with a
single command and no mounted files. The web UI and API are served on port 9093.

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
$ docker run -d --name alertmanager -p 9093:9093 \
  dhi.io/alertmanager:<tag>
```

Verify it's running:

```bash
$ curl http://localhost:9093/-/ready
OK
```

# Common Alertmanager use cases

## Mount a custom configuration

Override the bundled default config by mounting your own YAML file to `/etc/alertmanager/alertmanager.yml`.

```bash
$ docker run -d --name alertmanager -p 9093:9093 \
  -v /path/to/config.yml:/etc/alertmanager/alertmanager.yml:ro \
  dhi.io/alertmanager:<tag>
```

A minimal config that routes all alerts to a webhook receiver:

```yaml
route:
  receiver: 'webhook'
receivers:
  - name: 'webhook'
    webhook_configs:
      - url: 'http://example-receiver.local:5001/'
```

## Persist Alertmanager state

Alertmanager stores silence snapshots and notification log state on disk at `--storage.path`. The image pre-creates the
default path `/alertmanager` with ownership `65532:65532`, which matches the nonroot user the container runs as. Mount a
named volume to this path and no additional setup is required:

```bash
$ docker run -d --name alertmanager -p 9093:9093 \
  -v alertmanager_data:/alertmanager \
  dhi.io/alertmanager:<tag>
```

If you mount a volume to a different path, Docker auto-creates the target as `root:root`, which the nonroot user (UID
65532\) cannot write to. Alertmanager will start and serve requests, but will silently fail to persist state and log
`permission denied` errors on shutdown. Pre-chown the volume before starting Alertmanager:

```bash
$ docker volume create alertmanager_data
$ docker run --rm -v alertmanager_data:/data --user 0 \
    dhi.io/busybox:<tag> chown 65532:65532 /data
$ docker run -d --name alertmanager -p 9093:9093 \
  -v alertmanager_data:/data \
  dhi.io/alertmanager:<tag> \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/data
```

For host bind-mounts, run `chown 65532:65532` on the host directory before starting the container.

## Run with Prometheus using Docker Compose

Run Prometheus and Alertmanager together using Docker Compose. Prometheus reaches Alertmanager by service name on the
Compose network.

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    ports:
      - 9090:9090
  alertmanager:
    image: dhi.io/alertmanager:<tag>
    ports:
      - 9093:9093
    volumes:
      - ./alertmanager/config.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager

volumes:
  alertmanager_data: {}
```

In `prometheus.yml`, point Prometheus at Alertmanager:

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

# Non-hardened images vs Docker Hardened Images

## Key differences

| Feature         | Docker Official Alertmanager        | Docker Hardened Alertmanager                            |
| --------------- | ----------------------------------- | ------------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches            |
| Shell access    | Full shell (`sh`) available         | No shell in runtime variants                            |
| Package manager | `apk` available                     | No package manager in runtime variants                  |
| User            | Runs as root by default             | Runs as nonroot user (UID 65532)                        |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                      |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting     |
| Storage path    | `/alertmanager` (must chown)        | `/alertmanager` pre-created with `65532:65532`          |
| Compliance      | None                                | CIS; FIPS 140-3 and STIG in FIPS variants               |
| Attestations    | None                                | SBOM, provenance, VEX metadata, FIPS (on FIPS variants) |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- Docker Debug to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
$ docker debug alertmanager
```

Or mount debugging tools with the Image Mount feature:

```bash
$ docker run --rm -it --pid container:alertmanager \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/alertmanager:<tag> /dbg/bin/sh
```

For Alertmanager specifically, most operational inspection can also be done through the HTTP API without a shell:
`/-/ready`, `/-/healthy`, `/api/v2/status`, `/api/v2/alerts`, `/api/v2/silences`, and `/metrics`.

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

The Alertmanager image is published in the following variant combinations:

| Variant           | Tag pattern                                         | User    | Compliance      | Shell / package manager |
| ----------------- | --------------------------------------------------- | ------- | --------------- | ----------------------- |
| Runtime           | `<version>`, `<version>-debian13`                   | nonroot | CIS             | None                    |
| Runtime + FIPS    | `<version>-fips`, `<version>-debian13-fips`         | nonroot | CIS, FIPS, STIG | None                    |
| Build-time (dev)  | `<version>-dev`, `<version>-debian13-dev`           | root    | CIS             | Yes                     |
| Build-time + FIPS | `<version>-fips-dev`, `<version>-debian13-fips-dev` | root    | CIS, FIPS, STIG | Yes                     |

Alpine-based equivalents are also published with tag patterns `<version>-alpine3.23`, `<version>-alpine3.23-fips`, etc.

To view all published tags and get more information about each variant, select the Tags tab for this repository and
select a tag.

# FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

FIPS variants of the Alertmanager image are drop-in replacements for the standard runtime variant — they have the same
CMD, working directory, and nonroot user (UID 65532). No changes are required to the Alertmanager binary or config file
to run under FIPS mode.

## Pull a FIPS variant

```bash
$ docker pull dhi.io/alertmanager:<version>-fips
```

## Verify the FIPS attestation

FIPS variants include a signed FIPS attestation listing the cryptographic modules in the image and their validation
status. Retrieve it with Docker Scout:

```bash
$ docker scout attest get \
    --predicate-type https://docker.com/dhi/fips/v0.1 \
    --predicate \
    dhi.io/alertmanager:<version>-fips
```

Example attestation output:

```json
[
  {
    "name": "OpenSSL FIPS Provider",
    "package": "pkg:dhi/openssl-provider-fips@3.1.2",
    "standard": "FIPS 140-3",
    "status": "active",
    "certification": "CMVP #4985",
    "certificationUrl": "https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4985",
    "sunsetDate": "2030-03-10",
    "version": "3.1.2"
  },
  {
    "name": "Go Cryptographic Module",
    "package": "pkg:golang/golang.org/x/crypto@1.0.0#crypto/internal/fips140",
    "standard": "FIPS 140-3",
    "status": "in process",
    "version": "1.0.0"
  }
]
```

## Runtime requirements specific to FIPS

Alertmanager itself does not require any FIPS-specific configuration flags. TLS and webhook cryptographic operations
automatically use the FIPS-validated providers when the FIPS variant is running.

If you use Alertmanager integrations that depend on non-approved cryptographic algorithms (for example, webhook
endpoints requiring MD5 or 3DES), those algorithms are disabled in FIPS mode and will fail at runtime. Review your
receiver configurations for custom CA certificates signed with deprecated algorithms, `tls_config` blocks pinning
non-approved cipher suites, and webhook receivers requiring older TLS versions.

## What changes in FIPS mode

Compared to the standard runtime variant:

- **Cryptographic modules**: OpenSSL FIPS Provider 3.1.2 (CMVP #4985, active) and the Go FIPS 140-3 crypto module are
  used for all cryptographic operations.
- **Available algorithms**: only FIPS 140-approved algorithms are available. Non-approved algorithms fail at runtime
  rather than silently falling back.
- **Image size**: slightly larger due to the FIPS provider module.
- **Compliance labels**: carries `com.docker.dhi.compliance=fips,stig,cis`.
- **Everything else**: identical. Same Alertmanager version, same API, same config format, same nonroot UID 65532, same
  default CMD.

FIPS variants are appropriate for regulated environments such as FedRAMP, government, healthcare, financial services,
and defense deployments.

# Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                   |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                        |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                      |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (UID 65532). Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                           |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                                                                 |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                               |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Alertmanager's default port 9093 works without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                      |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use `dev` images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                    |
| Storage path       | Mount persistent volumes to `/alertmanager` (pre-created with ownership `65532:65532`). For custom paths, pre-chown the mount target to `65532:65532`.                                                                                                                           |

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

## General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use Docker Debug to attach to these containers. Docker
Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that
only exists during the debugging session.

For Alertmanager specifically, most operational debugging can be done through the HTTP API without a shell:

- `GET /-/ready` — readiness check
- `GET /-/healthy` — health check
- `GET /api/v2/status` — cluster and config status
- `GET /api/v2/alerts` — current alerts
- `GET /api/v2/silences` — current silences
- `GET /metrics` — Prometheus metrics

## Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

The most common permission issue with Alertmanager is mounting a volume to a custom storage path. Docker auto-creates
bind-mount and volume targets as `root:root`, which UID 65532 cannot write to. Alertmanager will start and appear
healthy but will silently fail to persist state, logging on shutdown:

```
level=ERROR msg="Creating shutdown snapshot failed"
  err="open /data/nflog.xxxxxxxx: permission denied"
```

Mount volumes to the default `/alertmanager` path (pre-created with correct ownership), or pre-chown custom paths to
`65532:65532` before starting the container.

## Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Alertmanager's
default port 9093 is above 1024 and is unaffected.

## No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

## Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. The Alertmanager image entry
point is the `alertmanager` binary with default CMD
`--config.file=/etc/alertmanager/alertmanager.yml --storage.path=/alertmanager`. To invoke the bundled `amtool` CLI,
override the entry point with `--entrypoint amtool`.
