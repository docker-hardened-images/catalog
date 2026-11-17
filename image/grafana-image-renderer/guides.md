## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Grafana Image Renderer Docker Hardened Image

This Docker Hardened Grafana Image Renderer image provides a headless browser service for rendering Grafana panels and
dashboards as PNG images and PDF documents. Built with Go and Chromium, it provides a standalone rendering engine that
can be used as a remote rendering service for Grafana instances.

The image includes:

- grafana-image-renderer (Go-based rendering service)
- Chromium browser (headless mode for rendering)
- Comprehensive font packages for internationalization (Japanese, Chinese, Thai, Arabic, and more)

### Start a Grafana Image Renderer instance

```bash
$ docker run -d --name grafana-renderer -p 8081:8081 \
  dhi.io/grafana-image-renderer:<tag>
```

The service will be accessible at `http://localhost:8081`. Check health at `http://localhost:8081/healthz`.

## Common use cases

### Using with Grafana (Docker Compose)

The following is a sample Docker Compose setup that includes Grafana and the rendering service:

```yaml
services:
  grafana:
    image: dhi.io/grafana:<tag>
    environment:
      - GF_RENDERING_SERVER_URL=http://renderer:8081/render
      - GF_RENDERING_CALLBACK_URL=http://grafana:3000/
    ports:
      - 3000:3000
    depends_on:
      - renderer

  renderer:
    image: dhi.io/grafana-image-renderer:<tag>
    ports:
      - 8081:8081
```

Configure Grafana to use the remote renderer in `/etc/grafana/grafana.ini`:

```ini
[rendering]
server_url = http://renderer:8081/render
callback_url = http://grafana:3000/
```

### With custom configuration

Mount a configuration file (JSON or YAML):

```bash
$ docker run -d --name grafana-renderer -p 8081:8081 \
  -v /path/to/config.yaml:/etc/grafana-image-renderer/config.yaml:ro \
  dhi.io/grafana-image-renderer:<tag> \
  server --config=/etc/grafana-image-renderer/config.yaml
```

Example `config.yaml`:

```yaml
browser:
  path: /usr/lib/chromium/chromium
  flags:
    - disable-gpu
    - window-size=1920,1080

server:
  host: 0.0.0.0
  port: 8081

log:
  level: info
```

### Use Grafana Image Renderer in Kubernetes

To use the Grafana Image Renderer hardened image in Kubernetes,
[set up authentication](https://docs.docker.com/dhi/how-to/k8s/) and update your Kubernetes deployment. For example, in
your deployment manifest, replace the image reference in the container spec. In the following example, replace `<tag>`
with the desired tag.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana-renderer
  namespace: monitoring
spec:
  replicas: 2
  selector:
    matchLabels:
      app: grafana-renderer
  template:
    metadata:
      labels:
        app: grafana-renderer
    spec:
      containers:
      - name: renderer
        image: dhi.io/grafana-image-renderer:<tag>
        ports:
        - containerPort: 8081
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "8Gi"
            cpu: "4"
        env:
        - name: GOMEMLIMIT
          value: "6GiB"
      imagePullSecrets:
      - name: <your-registry-secret>
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-renderer
  namespace: monitoring
spec:
  selector:
    app: grafana-renderer
  ports:
  - port: 8081
    targetPort: 8081
```

Then apply the manifest to your Kubernetes cluster:

```console
$ kubectl apply -f grafana-renderer.yaml
```

## Configuration

The service supports configuration via environment variables or command-line flags. Key options:

### Browser configuration

- `BROWSER_PATH` - Browser binary path (default: `/usr/lib/chromium/chromium`)
- `BROWSER_FLAGS` - Space-separated Chromium arguments
- `BROWSER_MIN_WIDTH` - Minimum viewport width (default: 800)
- `BROWSER_MIN_HEIGHT` - Minimum viewport height (default: 600)

### Server configuration

- `SERVER_HOST` - Bind address (default: `0.0.0.0`)
- `SERVER_PORT` - Listen port (default: `8081`)
- `LOG_LEVEL` - Log verbosity: `debug`, `info`, `warn`, `error` (default: `info`)

### Resource limits

Based on upstream guidance, the recommended resource allocation is:

- **Memory**: 2 GiB minimum, 8 GiB recommended for 10+ concurrent renders
- **CPU**: 1 core minimum, 4 cores for high-throughput scenarios

Set `GOMEMLIMIT` to approximately 75% of the memory limit to prevent out-of-memory errors.

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature        | Non-hardened Grafana Image Renderer | Docker Hardened Grafana Image Renderer  |
| -------------- | ----------------------------------- | --------------------------------------- |
| Base image     | Debian 13                           | Debian 13 hardened base                 |
| Security       | Standard image                      | Hardened with security patches and SBOM |
| User           | Runs as UID 65532 (nonroot)         | Runs as UID 65532 (nonroot)             |
| Shell access   | Available                           | No shell (runtime variant)              |
| Attack surface | Standard packages                   | Minimal packages                        |
| Chromium       | Included with all dependencies      | Included with minimal dependencies      |

<!-- Everything below here is boilerplate and should be included verbatim -->

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

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

The DHI Grafana image runs `grafana server` directly with explicit path arguments, rather than using a shell script like
the upstream image. This means:

- Standard usage works identically to upstream
- `GF_<SECTION>_<KEY>` environment variables work normally
- Some upstream environment variables have no effect (see the note in
  [Configure Grafana with environment variables](#configure-grafana-with-environment-variables))
