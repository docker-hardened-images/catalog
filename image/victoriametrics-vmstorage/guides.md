## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this VictoriaMetrics VMStorage Hardened Image

This Docker Hardened VictoriaMetrics VMStorage image includes the `vmstorage` component of the VictoriaMetrics
monitoring stack. The `vmstorage` service is responsible for storing and retrieving time series data. It works in
conjunction with other VictoriaMetrics components like `vminsert` (for data ingestion) and `vmselect` (for querying
data).

### Start a VictoriaMetrics VMStorage image

```bash
docker run -d --name victoriametrics-vmstorage -p 8482:8482 -p 8400:8400 -p 8401:8401 dhi.io/victoriametrics-vmstorage:<tag>
```

## Common use cases

### Install VictoriaMetrics using Helm

You can install VictoriaMetrics using the official helm chart and replace the image. Replace `<your-registry-secret>`
with your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>` with the desired image
tag.

```bash
helm repo add victoriametrics https://victoriametrics.github.io/helm-charts
helm repo update

helm upgrade --install victoria-metrics-cluster victoriametrics/victoria-metrics-cluster \
  -n victoriametrics --create-namespace --wait \
  --set "global.pullSecrets[0].name=<your-registry-secret>" \
  --set vmstorage.image.registry="" \
  --set vmstorage.image.repository="<IMAGE_REPOSITORY>" \
  --set vmstorage.image.tag="<IMAGE_TAG>" \
  --set vmstorage.podSecurityContext.enabled=true \
  --set vmstorage.podSecurityContext.fsGroup=65532 \
  --set vmstorage.securityContext.enabled=true \
  --set vmstorage.securityContext.runAsNonRoot=true \
  --set vmstorage.securityContext.runAsUser=65532 \
  --set vmstorage.securityContext.runAsGroup=65532
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened VictoriaMetrics VMStorage | Docker Hardened VictoriaMetrics VMStorage           |
| --------------- | -------------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities    | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available         | No shell in runtime variants                        |
| Package manager | apt/apk available                      | No package manager in runtime variants              |
| User            | Runs as root by default                | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities     | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging            | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/victoriametrics-vmstorage:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

## Migrate to a Docker Hardened Image

Switching to the hardened VictoriaMetrics VMStorage image does not require any special changes. You can use it as a
drop-in replacement for the standard VictoriaMetrics VMStorage (`victoriametrics/vmstorage`) image in your existing
workflows and configurations. Note that the entry point for the hardened image may differ from the standard image, so
ensure that your commands and arguments are compatible.

### Migration steps

1. Replace the image reference in your Docker run command or Compose file.

1. All your existing command-line arguments, environment variables, port mappings, and network settings remain the same.

1. Test your migration and use the troubleshooting tips below if you encounter any issues.

## Troubleshooting migration

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
