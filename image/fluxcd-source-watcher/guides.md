## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About Source Watcher

The source-watcher is a Flux CD reference controller that demonstrates the pattern for building custom controllers that
consume the Flux source API. It watches GitRepository, HelmRepository, and HelmChart objects managed by
source-controller and logs artifact revision changes. Use it as a blueprint for writing your own event-driven automation
on top of Flux source objects.

### Running the image

To verify the image and see available flags:

```bash
docker run --rm dhi.io/fluxcd-source-watcher:<tag> --help
```

### Deployment requirements

The source-watcher runs as a Kubernetes controller and requires:

- Access to the Kubernetes API server
- RBAC permissions to read GitRepository, HelmRepository, and HelmChart resources in the `flux-system` namespace
- A running Flux CD installation with source-controller managing source objects

When deployed, the controller connects to the Kubernetes API server and watches for changes to Flux source objects.

### Deploying to Kubernetes

Apply RBAC and a Deployment manifest that references the DHI image. For example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: source-watcher
  namespace: flux-system
spec:
  selector:
    matchLabels:
      app: source-watcher
  template:
    metadata:
      labels:
        app: source-watcher
    spec:
      serviceAccountName: source-watcher
      containers:
        - name: source-watcher
          image: dhi.io/fluxcd-source-watcher:<tag>
          securityContext:
            runAsNonRoot: true
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            seccompProfile:
              type: RuntimeDefault
            capabilities:
              drop:
                - ALL
```

### Version and Flux compatibility

The image version corresponds to the source-watcher release and the Flux source API version it targets:

| Image tag | Source API version          |
| --------- | --------------------------- |
| `2.x`     | source.toolkit.fluxcd.io/v1 |
| `1.3.x`   | source.toolkit.fluxcd.io/v1 |

### Common configuration options

The controller accepts standard controller-runtime flags:

- `--log-level`: Set logging verbosity (debug, info, warn, error)
- `--log-encoding`: Log format (json, console)
- `--metrics-bind-address`: Address for exposing Prometheus metrics (default `:8080`)
- `--health-probe-bind-address`: Address for health check endpoints (default `:8081`)
- `--leader-elect`: Enable leader election for HA deployments

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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                               |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                               |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   If you're using a multi-stage build, update the runtime stage to use a non-dev hardened image. This ensures your
   production containers run with minimal attack surface.

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

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
