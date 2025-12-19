## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start an Alloy instance

```bash
# Pull the public image
docker pull dhi.io/alloy:<tag>

# Create minimal config
cat > config.alloy << 'EOF'
logging {
  level  = "info"
  format = "logfmt"
}
prometheus.exporter.self "alloy" {}
prometheus.scrape "alloy" {
  targets    = prometheus.exporter.self.alloy.targets
  forward_to = []
}
EOF

# Start Alloy
docker run --rm -d \
  --name alloy-quick-test \
  -v "$PWD/config.alloy:/etc/alloy/config.alloy:ro" \
  -v alloy-data:/var/lib/alloy/data \
  -p 12345:12345 \
  dhi.io/alloy:<tag> \
  run /etc/alloy/config.alloy \
  --storage.path=/var/lib/alloy/data \
  --server.http.listen-addr=0.0.0.0:12345

# Wait for startup
sleep 5

# Check it's working
docker logs alloy-quick-test
curl http://localhost:12345/metrics | head -10

# Cleanup
docker rm -f alloy-quick-test
docker volume rm alloy-data
```

## Start a Grafana Alloy container

Assuming that `config.alloy` file is available in your current directory that contains the configuration for Alloy, you
can run the following command to start the container with a bind mount to the `config.alloy` file and a named volume for
Alloy's data.

```bash
docker run --rm \
  -v "$PWD/config.alloy:/etc/alloy/config.alloy:ro" \
  -v alloy-data:/var/lib/alloy/data \
  -p 12345:12345 \
  dhi.io/alloy:<tag> \
  run /etc/alloy/config.alloy \
  --storage.path=/var/lib/alloy/data \
  --server.http.listen-addr=0.0.0.0:12345
```

The container starts using the default entrypoint, `alloy`, and command,
`run /etc/alloy/config.alloy --storage.path=/var/lib/alloy/data`.

## Use cases

### Use case 1: Send metrics to Prometheus

This example shows how to collect Alloy's internal metrics and forward them to Prometheus using the remote write API.

**Step 1: Create a Docker network**

```bash
docker network create monitoring
```

**Step 2: Create the configuration file**

Create `config-prometheus.alloy`:

```alloy
logging {
  level  = "info"
  format = "logfmt"
}

prometheus.exporter.self "alloy" {}

prometheus.scrape "alloy" {
  targets    = prometheus.exporter.self.alloy.targets
  forward_to = [prometheus.remote_write.prom.receiver]
}

prometheus.remote_write "prom" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}
```

**Step 3: Verify the configuration**

```bash
cat config-prometheus.alloy
```

**Step 4: Start Prometheus (if not already running)**

```bash
docker run -d \
  --name prometheus \
  --network monitoring \
  -p 9090:9090 \
  prom/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --web.enable-remote-write-receiver
```

**Step 5: Start Alloy**

```bash
docker run --rm -d \
  --name alloy \
  -v "$PWD/config-prometheus.alloy:/etc/alloy/config.alloy:ro" \
  -v alloy-data:/var/lib/alloy/data \
  -p 12345:12345 \
  --network monitoring \
  dhi.io/alloy:<tag> \
  run /etc/alloy/config.alloy \
  --storage.path=/var/lib/alloy/data \
  --server.http.listen-addr=0.0.0.0:12345
```

**Step 6: Verify Alloy is running**

```bash
docker logs alloy
```

You should see: `msg="now listening for http traffic" addr=0.0.0.0:12345`

### Use case 2: Collect Docker container metrics

This example shows how to automatically discover and scrape metrics from running Docker containers using Docker socket
access.

**Step 1: Ensure the monitoring network exists**

If you already completed Use Case 1, the `monitoring` network already exists. If not, create it:

```bash
docker network create monitoring
```

**Step 2: Create the configuration file**

Create `config-docker.alloy`:

```alloy
logging {
  level  = "info"
  format = "logfmt"
}

discovery.docker "containers" {
  host = "unix:///var/run/docker.sock"
}

prometheus.scrape "docker" {
  targets    = discovery.docker.containers.targets
  forward_to = [prometheus.remote_write.prom.receiver]
}

prometheus.remote_write "prom" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}
```

**Step 3: Verify the configuration**

```bash
cat config-docker.alloy
```

**Step 4: Start Prometheus (if not already running)**

```bash
docker run -d \
  --name prometheus \
  --network monitoring \
  -p 9090:9090 \
  prom/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --web.enable-remote-write-receiver
```

**Step 5: Start Alloy with Docker socket access**

```bash
docker run --rm -d \
  --name alloy \
  -v "$PWD/config-docker.alloy:/etc/alloy/config.alloy:ro" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v alloy-data:/var/lib/alloy/data \
  -p 12345:12345 \
  --network monitoring \
  dhi.io/alloy:<tag> \
  run /etc/alloy/config.alloy \
  --storage.path=/var/lib/alloy/data \
  --server.http.listen-addr=0.0.0.0:12345
```

**Step 6: Verify Alloy is running**

```bash
docker logs alloy
```

You should see: `msg="now listening for http traffic" addr=0.0.0.0:12345`

## Image variants

The Alloy Hardened Image is available as dev and runtime variants.

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

**Runtime variants** are designed to run your application in production. These images are intended to be used either
directly or as the FROM image in the final stage of a multi-stage build. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

**Build-time variants** typically include `dev` in the tag name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

## Non-hardened images vs Docker Hardened Images

Based on empirical testing, here are the key differences:

| Feature           | Standard Grafana Alloy       | Docker Hardened Grafana Alloy                   |
| ----------------- | ---------------------------- | ----------------------------------------------- |
| Base Image        | Standard base with utilities | Debian 13 with security patches                 |
| Shell access      | Shell available (sh)         | No shell in runtime variants                    |
| Image size        | 641MB                        | 510MB runtime / 606MB dev (optimized)           |
| Layers            | 18 layers                    | 10 layers (more efficient)                      |
| User              | Default user                 | Runs as alloy user (UID 473)                    |
| Security patches  | Standard update cycle        | Proactive security patches and hardening        |
| Image variants    | Production image only        | Runtime (production) + Dev (debugging) variants |
| Dev/Debug support | Shell-based debugging        | Dev variant with bash, apt, and debugging tools |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened runtime images don't contain a shell nor any tools for debugging. For Grafana Alloy, debugging options
include:

- **DHI Dev variant**: Use `dhi.io/alloy:<tag>-dev` with entrypoint override
  ```bash
  docker run --rm -it --entrypoint=/bin/bash dhi.io/alloy:<tag>-dev
  ```
- **Docker Debug**: Attach ephemeral debugging tools to running containers
- **Container logs**: Use `docker logs` to inspect application output

The dev variant includes bash, apt, and standard utilities, but requires overriding the entrypoint since the default is
still to run Alloy. This design ensures the dev variant can be used for both debugging (with entrypoint override) and
testing (with default behavior).

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                            |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the **Tags** tab for this repository. To view what packages are already installed in an image variant, select
   the **Tags** tab for this repository, and then select a tag.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Debian-based images, you can use `apt-get` to install packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use Docker Debug to attach to these containers. Docker
Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that
only exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

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

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
