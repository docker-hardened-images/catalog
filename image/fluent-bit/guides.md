## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>` For the examples, you must first use `docker login dhi.io`
  to authenticate to the registry to pull the images.

# Start a Fluent Bit instance

Run the following command to start a Fluent Bit container. The image's entrypoint is the `fluent-bit` binary, and a
reference configuration is bundled read-only at `/fluent-bit/etc/conf/fluent-bit.conf` inside the image. Unlike some
Fluent Bit distributions, the hardened image does **not** auto-load a configuration file at startup — you must pass a
config explicitly with the `-c` flag when you need inputs, filters, or outputs. To use your own configuration, replace
`<path-to-your-configuration-file>` with the path to your `fluent-bit.conf` file.

```bash
# Start with the bundled reference config
$ docker run --rm --name my-fluentbit -p 24224:24224 \
  dhi.io/fluent-bit:<tag> \
  -c /fluent-bit/etc/conf/fluent-bit.conf

# Start with a custom config
$ docker run --rm --name my-fluentbit -p 24224:24224 \
  -v <path-to-your-configuration-file>:/fluent-bit/etc/conf/fluent-bit.conf:ro \
  dhi.io/fluent-bit:<tag> \
  -c /fluent-bit/etc/conf/fluent-bit.conf
```

The image exposes `24224/tcp` (Forward input), `9880/tcp` (HTTP input), and `2020/tcp` (built-in HTTP server for health
and metrics). Publish any ports your configuration uses with `-p`. Note that port `2020` only listens when
`http_server On` is set in the `[SERVICE]` block of your config — the port is exposed in image metadata but nothing
binds to it by default.

# Common Fluent Bit use cases

## Basic log forwarding with HTTP input

Create a configuration that accepts JSON payloads on port 9880 and prints them to stdout:

Create `fluent-bit.conf`:

```conf
[SERVICE]
    flush        1
    log_level    info
    http_server  On
    http_listen  0.0.0.0
    http_port    2020

[INPUT]
    name http
    host 0.0.0.0
    port 9880

[OUTPUT]
    name  stdout
    match *
```

Run Fluent Bit with the configuration:

```bash
$ docker run -d --name fluent-bit -p 9880:9880 -p 2020:2020 \
  -v $(pwd)/fluent-bit.conf:/fluent-bit/etc/conf/fluent-bit.conf:ro \
  dhi.io/fluent-bit:<tag> \
  -c /fluent-bit/etc/conf/fluent-bit.conf
```

Send a JSON log entry and verify it appears in the container logs:

```bash
$ curl -X POST -H 'Content-Type: application/json' \
    -d '{"message":"hello world"}' \
    http://localhost:9880/test.log

$ docker logs fluent-bit | tail -2
[0] test.log: [[1776688797.501994961, {}], {"message"=>"hello world"}]
```

Verify the built-in HTTP server is running:

```bash
$ curl http://localhost:2020/
{"fluent-bit":{"version":"4.2.4","edition":"Community", ... }}
```

## Deploy to Kubernetes with the DHI Helm chart

For Kubernetes deployments, use the Docker Hardened Helm chart at `oci://dhi.io/fluent-bit-chart`. The chart pins all
container images (Fluent Bit, configmap-reload, and the test BusyBox) by SHA256 digest, so you get supply-chain
integrity without extra configuration.

**Step 1: Create an image pull secret.** The DHI registry requires authentication for cluster pulls. Create a Kubernetes
secret using your Docker Hub credentials:

```bash
$ kubectl create secret docker-registry helm-pull-secret \
    --docker-server=dhi.io \
    --docker-username=<Docker username> \
    --docker-password=<Docker token> \
    --docker-email=<Docker email>
```

Use a Docker Hub personal access token (not your account password). For more detail, see the
[DHI Kubernetes authentication guide](https://docs.docker.com/dhi/how-to/k8s/).

**Step 2: Install the chart.** Replace `<tag>` with a published chart version (for example, `0.57.3`):

```bash
$ helm install my-fluent-bit oci://dhi.io/fluent-bit-chart --version <tag> \
    --set "imagePullSecrets[0].name=helm-pull-secret"
```

The chart deploys a DaemonSet that tails container logs on each node, enriches records with Kubernetes pod metadata via
the Kubernetes API, and forwards them to configured outputs.

**Step 3: Verify the deployment.**

```bash
$ kubectl get daemonset,pod -l app.kubernetes.io/instance=my-fluent-bit
NAME                                            DESIRED   CURRENT   READY   AGE
daemonset.apps/my-fluent-bit-fluent-bit-chart   2         2         2       15s

NAME                                       READY   STATUS    RESTARTS   AGE
pod/my-fluent-bit-fluent-bit-chart-bcz69   1/1     Running   0          15s
pod/my-fluent-bit-fluent-bit-chart-zn7td   1/1     Running   0          15s
```

Confirm the running pods are the digest-pinned DHI image:

```bash
$ kubectl get pod -l app.kubernetes.io/instance=my-fluent-bit \
    -o jsonpath='{.items[0].spec.containers[0].image}'
dhi.io/fluent-bit:4.2.4-debian13@sha256:817c1d8898b31ab5b06dd393ae8ebf92f0230da3cbf4a2673d8fee45b93b32de
```

Port-forward to a pod and hit the Fluent Bit HTTP server:

```bash
$ export POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=my-fluent-bit \
    -o jsonpath="{.items[0].metadata.name}")
$ kubectl port-forward $POD_NAME 2020:2020
$ curl http://127.0.0.1:2020/
```

To customize outputs, parsers, or filters, override the `config` values when installing the chart. See the chart's
values schema: `helm show values oci://dhi.io/fluent-bit-chart --version <tag>`.

To uninstall:

```bash
$ helm -n default uninstall my-fluent-bit
```

## Inspect health and metrics

Fluent Bit exposes a built-in HTTP server when `http_server On` is set. It provides operational endpoints useful for
liveness probes, Prometheus scraping, and runtime inspection:

```bash
$ curl http://localhost:2020/               # build info and compiled features
$ curl http://localhost:2020/api/v1/health  # liveness
$ curl http://localhost:2020/api/v1/uptime  # uptime
$ curl http://localhost:2020/api/v1/metrics/prometheus  # Prometheus metrics
```

# Non-hardened images vs Docker Hardened Images

## Key differences

| Feature             | Docker Official Fluent Bit          | Docker Hardened Fluent Bit                                      |
| ------------------- | ----------------------------------- | --------------------------------------------------------------- |
| Security            | Standard base with common utilities | Minimal, hardened Debian 13 base with security patches          |
| Shell access        | Full shell available                | `bash` available but not intended for production use            |
| Package manager     | `apk`/`apt` available               | No package manager in runtime variants                          |
| User                | Runs as root by default             | Runs as nonroot user (UID 65532)                                |
| Attack surface      | Larger due to additional utilities  | Minimal — coreutils and bash only, no networking or build tools |
| Plugin installation | Direct install in runtime           | Multi-stage build with a `dev` variant required                 |
| Debugging           | Traditional shell debugging         | Shell + HTTP API; Docker Debug for deeper inspection            |
| Compliance          | None                                | CIS; FIPS 140-3 + STIG in FIPS variants (subscription)          |
| Attestations        | None                                | SBOM, provenance, VEX metadata                                  |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities

- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment

- **Compliance ready**: Meets strict security requirements for regulated environments The Fluent Bit hardened image
  includes `bash` and GNU coreutils for config templating and entrypoint scripting, but deliberately omits package
  managers, network utilities (`curl`, `wget`), editors, and process inspection tools (`ps`, `top`, `find`). Common
  debugging methods for applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers

- Docker's Image Mount feature to mount debugging tools

- Fluent Bit's built-in HTTP server on port 2020 for health, uptime, and metrics Docker Debug provides a shell, common
  debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists during the
  debugging session. For example:

```bash
$ docker debug fluent-bit
```

Or mount debugging tools with the Image Mount feature:

```bash
$ docker run --rm -it --pid container:fluent-bit \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/fluent-bit:<tag>
```

# Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (UID 65532)

- Do not include a package manager

- Contain only the minimal set of libraries needed to run the app Build-time variants include `dev` in the variant name
  and are intended for use in the first stage of a multi-stage Dockerfile. These images typically:

- Run as the root user

- Include a shell and package manager

- Are used to build or compile applications, or to install additional Fluent Bit plugins and dependencies To view all
  published tags and get more information about each variant, select the Tags tab for this repository.

# FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

The Fluent Bit FIPS variants are available through DHI Select and DHI Enterprise subscriptions only. To pull them,
mirror the repository into your own namespace and pull from your mirror. See
[Mirror a DHI repository](https://docs.docker.com/dhi/how-to/mirror/).

FIPS variants of the Fluent Bit image carry the compliance labels `fips,stig,cis` and are drop-in replacements for the
standard runtime variant — same entrypoint, same nonroot UID 65532. No changes are required to the Fluent Bit binary or
config file to run under FIPS mode.

## Verify the FIPS attestation

FIPS variants include a signed FIPS attestation listing the cryptographic modules in the image and their validation
status. Retrieve it with Docker Scout against your mirrored repository:

```bash
$ docker scout attest get \
    --predicate-type https://docker.com/dhi/fips/v0.1 \
    --predicate \
    <your-namespace>/dhi-fluent-bit:<tag>-fips
```

## Runtime requirements specific to FIPS

Fluent Bit itself does not require any FIPS-specific configuration flags. TLS operations for outputs (Elasticsearch,
HTTP, Forward, Kafka, etc.) automatically use the FIPS-validated cryptographic providers.

If you use outputs that depend on non-approved cryptographic algorithms (for example, legacy TLS 1.0/1.1 endpoints or
certificates signed with MD5), those will fail at runtime rather than silently falling back. Review your `tls.*`
settings and certificate chain for FIPS compatibility before deploying a FIPS variant.

## What changes in FIPS mode

Compared to the standard runtime variant:

- **Cryptographic modules**: OpenSSL FIPS Provider is used for all cryptographic operations
- **Available algorithms**: only FIPS 140-approved algorithms are available
- **Image size**: slightly larger due to the FIPS provider module
- **Compliance labels**: carries `com.docker.dhi.compliance=fips,stig,cis`
- **Everything else**: identical. Same Fluent Bit version, same CLI, same config format, same nonroot UID 65532 FIPS
  variants are appropriate for regulated environments such as FedRAMP, government, healthcare, financial services, and
  defense deployments.

# Migrate to a Docker Hardened Image

To migrate your Fluent Bit deployment to a Docker Hardened Image, you must update your Dockerfile or Compose file. At
minimum, update the base image. The following table lists the most common changes:

| Item                | Migration note                                                                                                                                                                                                                                                  |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image          | Replace your base image with `dhi.io/fluent-bit:<tag>` for runtime, and `dhi.io/fluent-bit:<tag>-dev` for build stages.                                                                                                                                         |
| Package management  | Runtime variants don't contain a package manager. Install packages and plugins only in images with a `dev` tag.                                                                                                                                                 |
| Non-root user       | Runtime variants run as UID 65532. Ensure configuration files, position databases (`DB`), and any host volumes Fluent Bit writes to are accessible to this UID.                                                                                                 |
| Configuration path  | The hardened image uses the upstream Fluent Bit convention `/fluent-bit/etc/conf/fluent-bit.conf`. Mount custom configs to this path and pass `-c` explicitly — the image does not auto-load a config.                                                          |
| Multi-stage build   | Use a `dev` tag for build stages and a runtime variant for the final stage.                                                                                                                                                                                     |
| TLS certificates    | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates for typical output plugins.                                                                                                                   |
| Ports               | Runtime variants run as a nonroot user, so Fluent Bit can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The default Fluent Bit ports (9880, 24224, 2020) are all above 1024 and unaffected. |
| Entry point         | The image's entrypoint is `/usr/local/bin/fluent-bit`. There is no default CMD — you must pass `-c <config-path>` explicitly or define a CMD in your Dockerfile.                                                                                                |
| No shell            | Runtime variants include `bash` but no package manager, editors, or network utilities. Use `dev` images in build stages to run install commands and copy artifacts to the runtime stage.                                                                        |
| Plugin installation | Install custom plugins in a build stage using a `dev` image, then copy the plugin `.so` files into the runtime image.                                                                                                                                           |

The following steps outline the general migration process.

1. **Find hardened images for your app.** A hardened image may have several variants. Inspect the image tags and find
   the image variant that meets your needs.
1. **Update the base image in your Dockerfile.** Update the base image in your application's Dockerfile to the hardened
   image you found in the previous step. For plugin installation, use an image tagged as `dev` because it has the tools
   needed to install packages and dependencies.
1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.** To ensure that your final image is as
   minimal as possible, you should use a multi-stage build. All stages in your Dockerfile should use a hardened image.
   While intermediary stages will typically use images tagged as `dev`, your final runtime stage should use a runtime
   variant.
1. **Install additional packages.** Docker Hardened Images contain minimal packages in order to reduce the potential
   attack surface. For Fluent Bit plugins, install them in the build stage using a `dev` image and copy the necessary
   artifacts to the runtime stage.

# Troubleshoot migration

## General debugging

The hardened image includes `bash` and GNU coreutils but no networking or package-management tools. Most operational
debugging can be done through Fluent Bit's built-in HTTP server on port 2020 (see
[Inspect health and metrics](#inspect-health-and-metrics) for the available endpoints).

For deeper inspection, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to a running
container with a full debugging toolchain.

## Permissions

By default runtime variants run as the nonroot user (UID 65532). Ensure that necessary files and directories are
accessible to this UID:

```dockerfile
COPY --chown=65532:65532 fluent-bit.conf /fluent-bit/etc/conf/fluent-bit.conf
```

Fluent Bit's position database (`DB` setting on the `tail` input), filesystem storage path (`storage.path`), and any
host volumes it writes to must all be writable by UID 65532. Docker auto-creates named volumes as `root:root`, which the
nonroot user cannot write to — either pre-chown the volume or use a `fsGroup: 65532` `securityContext` in Kubernetes.

## Privileged ports

Runtime variants run as a nonroot user by default. Applications in these images can't bind to privileged ports (below
1024\) when running in Kubernetes or in Docker Engine versions older than 20.10. Fluent Bit's default ports (9880, 24224,
and 2020) are all above 1024 and are unaffected. If you configure custom input sources, ensure they also use ports above
1024\.

## No shell

Runtime variants include `bash` but omit package managers, editors, and networking tools. For build-time tasks
(installing plugins, compiling custom outputs, templating configs) use the `dev` variant. For runtime debugging beyond
Fluent Bit's HTTP API, use Docker Debug.

## Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
