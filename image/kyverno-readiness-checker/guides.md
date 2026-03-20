## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Kyverno Readiness Checker Hardened image

This image contains `readiness-checker`, a Kyverno component that checks if reports server endpoints are ready and HTTP
endpoints avaialble. This is usually used to test a Kyverno installation.

## Start a Kyverno Readiness Checker instance

Run the following command and replace `<tag>` with the image variant you want to run.

**Note:** `kyverno-readiness-checker` is primarily designed to run within a Kubernetes cluster as part of the complete
Kyverno deployment. The following standalone Docker command displays the available configuration options.

```bash
docker run --rm -it dhi.io/kyverno-readiness-checker:<tag> --help
```

## Common Kyverno Readiness Checker use cases

### Install Kyverno using Helm

You can install Kyverno using the official helm chart and replace the image. Replace `<your-registry-secret>` with your
[Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>` with the desired image tag.

```bash
helm repo add kyverno https://kyverno.github.io/kyverno
helm repo update

helm upgrade --install kyverno kyverno/kyverno \
  -n kyverno --create-namespace --wait \
  --set "images.pullSecrets[0].name=<your-registry-secret>" \
  --set image.registry=dhi.io \
  --set test.image.repository=kyverno-readiness-checker \
  --set test.image.tag=<tag> \
  --set test.podSecurityContext.runAsUser=65532
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Kyverno Readiness Checker | Docker Hardened Kyverno Readiness Checker           |
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

### Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug dhi-kyverno-readiness-checker
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/kyverno-readiness-checker:<tag> /dbg/bin/sh
```

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

To migrate your application to a Docker Hardened Image, you must update your Kubernetes manifests or Docker
configurations. At minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This
and a few other common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                            |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Kubernetes manifests with a Docker Hardened Image.                                                                                                                       |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. `kyverno-readiness-checker` binds to port 8000 for metrics by default. Because hardened images run as nonroot, avoid privileged ports (\<1024). |
| Entry point        | Docker Hardened Images may have different entry points than standard kyverno images. Inspect entry points for Docker Hardened Images and update your deployment if necessary.                             |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                               |

## Troubleshoot migration

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
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
