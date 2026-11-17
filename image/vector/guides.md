## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Vector Hardened image

Vector is a high-performance observability data pipeline from Datadog that collects, transforms, and routes logs,
metrics, and traces. It is commonly deployed as a per-host or per-node agent, or as a central aggregator that receives
data from many agents and forwards it to sinks such as Elasticsearch, Loki, Kafka, S3, and many others.

This Docker Hardened Vector image includes:

- `vector` (the main binary at `/usr/local/bin/vector`, set as the image entrypoint)
- A working default configuration at `/etc/vector/vector.yaml` (a `demo_logs` source → `remap` transform → `console`
  sink pipeline) so the image runs out of the box without any user configuration

The image declares port `8686/tcp` for Vector's API endpoint. The API itself is disabled in the default configuration;
enable it by adding an `api:` block to your own configuration.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

### Start a Vector container

Because the image ships with a working default configuration, it runs immediately with no flags or mounts:

```bash
$ docker run --rm dhi.io/vector:<tag>
```

Vector loads the default config and starts emitting synthetic syslog events to stdout in pretty-printed JSON. This is
useful for confirming the image works in your environment before mounting your own pipeline.

To run in the background and expose the API port (only useful once the API is enabled in your config):

```bash
$ docker run -d --name vector -p 8686:8686 dhi.io/vector:<tag>
```

### Common Vector use cases

#### Provide your own pipeline configuration

For real workloads, mount your own YAML configuration over the default at `/etc/vector/vector.yaml`:

```bash
$ docker run -d --name vector \
    -p 8686:8686 \
    -v /path/to/vector.yaml:/etc/vector/vector.yaml:ro \
    dhi.io/vector:<tag>
```

A minimal config that enables the API and tails log files:

```yaml
api:
  enabled: true
  address: "0.0.0.0:8686"

sources:
  app_logs:
    type: file
    include:
      - /var/log/app/*.log

sinks:
  out:
    type: console
    inputs: ["app_logs"]
    encoding:
      codec: json
```

If your source reads files from the host, also mount the host directory read-only:

```bash
$ docker run -d --name vector \
    -p 8686:8686 \
    -v /path/to/vector.yaml:/etc/vector/vector.yaml:ro \
    -v /var/log/app:/var/log/app:ro \
    dhi.io/vector:<tag>
```

#### Verify Vector is healthy via the API

When the API is enabled (`api.enabled: true` in your configuration), Vector exposes a `/health` endpoint suitable for
liveness checks:

```bash
$ curl http://localhost:8686/health
{"ok":true}
```

The same port also hosts a GraphQL endpoint at `/graphql`, which backs the `vector top` interactive monitoring command
and the Vector Tap functionality for inspecting events flowing through the pipeline.

#### Run with Docker Compose

```yaml
services:
  vector:
    image: dhi.io/vector:<tag>
    container_name: vector
    ports:
      - "8686:8686"
    volumes:
      - ./config/vector.yaml:/etc/vector/vector.yaml:ro
    restart: unless-stopped
```

Place your pipeline configuration at `./config/vector.yaml` next to the compose file and start with
`docker compose up -d`.

#### Deploy on Kubernetes

Vector on Kubernetes typically runs as either a `Deployment` (aggregator role, receiving from many agents) or a
`DaemonSet` (agent role, one pod per node). The example below is the aggregator pattern with a `ConfigMap` for the
pipeline configuration.

The `imagePullSecrets` field references a pull secret you must create first for `dhi.io` — see
[DHI authentication in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/).

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vector-config
data:
  vector.yaml: |
    api:
      enabled: true
      address: "0.0.0.0:8686"
    sources:
      demo:
        type: demo_logs
        format: syslog
        interval: 1
    sinks:
      out:
        type: console
        inputs: ["demo"]
        encoding:
          codec: json
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vector
  template:
    metadata:
      labels:
        app: vector
    spec:
      imagePullSecrets:
        - name: helm-pull-secret
      containers:
        - name: vector
          image: dhi.io/vector:<tag>
          ports:
            - name: api
              containerPort: 8686
          volumeMounts:
            - name: config
              mountPath: /etc/vector
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: vector-config
```

Apply with `kubectl apply -f vector.yaml`. To verify the API is reachable:

```bash
$ POD=$(kubectl get pod -l app=vector -o jsonpath='{.items[0].metadata.name}')
$ kubectl port-forward $POD 8686:8686
$ curl http://localhost:8686/health
{"ok":true}
```

### Non-hardened images vs Docker Hardened Images

#### Key differences

| Feature         | Docker Official Vector           | Docker Hardened Vector                                               |
| --------------- | -------------------------------- | -------------------------------------------------------------------- |
| Security        | Standard Debian base             | Minimal, hardened Debian 13 base                                     |
| Shell access    | Full shell available             | No shell                                                             |
| Package manager | `apt`, `apt-get`, `dpkg` present | No package manager                                                   |
| User            | Runs as root (`USER` unset)      | Runs as nonroot user (UID 65532)                                     |
| Default command | None — requires a config flag    | Built-in `--config /etc/vector/vector.yaml` + working default config |
| Attack surface  | Larger due to apt toolchain      | Reduced — no shell, no package manager, nonroot                      |
| Debugging       | Traditional shell debugging      | Use Docker Debug or Image Mount for troubleshooting                  |
| Compliance      | None                             | CIS                                                                  |
| Attestations    | None                             | SBOM, provenance, VEX metadata                                       |

These are not generic claims — they reflect direct inspection of the upstream `timberio/vector:latest-debian` image and
`dhi.io/vector:<tag>`. The DHI variant runs as a nonroot user, ships without `apt`/`apt-get`/`dpkg`, has no shell at
all, and includes a working default config so the image runs without arguments.

#### Why no shell?

Vector is a single Rust binary with no runtime dependency on shell scripts, so the runtime variant ships without `bash`,
`/bin/sh`, or any other shell. This is more aggressive minimalism than some other Docker Hardened Images (where
shell-script collectors require keeping bash present).

For debugging, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/), which provides an ephemeral
shell session:

```bash
$ docker debug vector
```

For operational visibility without a shell, enable Vector's API (`api.enabled: true`) and use `vector top` or
`vector tap` from another machine to inspect the running pipeline.

### Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (UID 65532)
- Do not include a shell or a package manager
- Contain only the Vector binary and the minimal set of libraries needed to run it

Build-time variants include `dev` in the variant name and are intended for use in the first stage of a multi-stage
Dockerfile. These images typically:

- Run as the root user
- Include a shell (`bash`) and a package manager (`apt`)
- Are used to build or compile applications, or to install additional tooling alongside Vector

The Vector image is published in the following variants:

| Variant          | Tag pattern                           | User    | Compliance | Availability |
| ---------------- | ------------------------------------- | ------- | ---------- | ------------ |
| Runtime          | `<major>`, `<major>-debian13`         | nonroot | CIS        | Public       |
| Build-time (dev) | `<major>-dev`, `<major>-debian13-dev` | root    | CIS        | Public       |

To view all published tags and get more information about each variant, select the **Tags** tab for this repository.

### Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or runtime configuration. At
minimum, you must update the base image to a Docker Hardened Image. This and a few other common changes are listed in
the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                               |
| :----------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base image with `dhi.io/vector:<tag>`.                                                                                                                                                                                                                                                          |
| Package management | The runtime image doesn't contain a package manager. To install additional tooling, build your own image `FROM dhi.io/vector:<tag>-dev` in a separate build stage and use `apt-get` there.                                                                                                                   |
| Non-root user      | The image runs as the nonroot user (UID 65532). Ensure that any mounted configuration files, data directories, or input log files are readable by UID 65532. Output directories must be writable by UID 65532. With named Docker volumes this works automatically; with bind mounts, check host permissions. |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                                                                                             |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates for sinks that use HTTPS or TLS.                                                                                                                                                           |
| Ports              | The image declares port 8686 (Vector API). The default is above 1024 and unaffected by the privileged-port restriction for nonroot containers. If your pipeline uses additional source ports (HTTP, syslog, Vector source/sink protocols), use ports above 1024.                                             |
| Entry point        | The entrypoint is `/usr/local/bin/vector` with default CMD `--config /etc/vector/vector.yaml`. To pass additional flags or run subcommands like `vector validate`, append them to the docker run command after the image reference.                                                                          |
| No shell           | The runtime image has no shell. Use the `dev` variant for build stages that need to run shell commands, then copy artifacts to the runtime stage.                                                                                                                                                            |
| Image pull secret  | For Kubernetes deployments, create a pull secret for `dhi.io` and reference it in `imagePullSecrets`.                                                                                                                                                                                                        |

### Troubleshoot migration

The following are common issues that you may encounter during migration.

#### General debugging

The hardened runtime image doesn't contain a shell or any tools for debugging. The recommended method for debugging
applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

For Vector-specific troubleshooting:

- The container's stdout logs include Vector's structured startup messages and any config or healthcheck errors
- Validate a configuration without starting the full pipeline:
  `docker run --rm -v /path/to/vector.yaml:/etc/vector/vector.yaml:ro dhi.io/vector:<tag> validate /etc/vector/vector.yaml`
- When the API is enabled, `vector top` (run from another host or the dev variant) provides a real-time view of
  source/transform/sink throughput

#### Permissions

The image runs as UID 65532. Mounted files Vector reads (configuration, input logs) must be readable by this UID.
Mounted directories Vector writes to (the data directory at `/var/lib/vector` if enabled, sink output paths) must be
writable by UID 65532.

#### Privileged ports

The image runs as nonroot, so Vector cannot bind to ports below 1024. The default API port 8686 is unaffected. If your
pipeline includes sources that listen on traditional ports (such as syslog on 514), configure them to listen on a port
above 1024 inside the container and map a lower host port at the publish step (`docker run -p 514:5514`).

#### Entry point

The image's default ENTRYPOINT is `/usr/local/bin/vector` and CMD is `--config /etc/vector/vector.yaml`. To pass extra
Vector flags, append them after the image reference. To run a different subcommand (such as `vector validate` or
`vector graph`), supply those arguments to replace the default CMD:

```bash
$ docker run --rm dhi.io/vector:<tag> --version
$ docker run --rm dhi.io/vector:<tag> validate /etc/vector/vector.yaml
```

Use `docker inspect` to view the entrypoint and default CMD for a specific tag.
