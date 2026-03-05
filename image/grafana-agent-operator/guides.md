## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Grafana Agent Operator Hardened image

This image contains Grafana Agent Operator, a Kubernetes operator built to help you manage your Grafana instances and
its resources in and outside of Kubernetes. You can still run it with the Docker cli to get help about the different
configuration options.

> **Note**: Grafana Agent has been deprecated and is in Long-Term Support mode. Grafana recommends migrating to Grafana
> Alloy, the next-generation collector built on Grafana Agent Flow. Docker Hardened Images provides an
> [Alloy hardened image](https://hub.docker.com/r/grafana/alloy). For migration guidance, see the
> [Alloy migration documentation](https://grafana.com/docs/alloy/latest/tasks/migrate/).

## Common Grafana Agent Operator use cases

### Install Grafana Operator using Helm

You can install Grafana Operator using the official helm chart and replace the image. Replace `<your-registry-secret>`
with your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>` with the desired image
tag.

```bash
helm upgrade --install test-grafana-agent-operator ghcr.io/grafana/helm-charts/grafana-agent-operator \
  --set "image.pullSecrets[0]=<your-registry-secret>" \
  --set image.registry=dhi.io \
  --set image.repository=grafana-agent-operator \
  --set image.tag=<tag> \
  --version <version>
```

That should start the operator:

```console
NAME                                              READY   STATUS    RESTARTS   AGE
pod/test-grafana-agent-operator-d5489d59c-dr2g8   1/1     Running   0          13s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                        AGE
service/kubelet      ClusterIP   None         <none>        10250/TCP,10255/TCP,4194/TCP   13s
service/kubernetes   ClusterIP   10.43.0.1    <none>        443/TCP                        26s

NAME                                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/test-grafana-agent-operator   1/1     1            1           14s

NAME                                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/test-grafana-agent-operator-d5489d59c   1         1         1       14s
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature               | Non-hardened Grafana Agent          | Docker Hardened Grafana Agent                              |
| --------------------- | ----------------------------------- | ---------------------------------------------------------- |
| Base image            | Alpine or Ubuntu-based              | Debian hardened base                                       |
| Security              | Standard image with basic utilities | Hardened build with security patches and security metadata |
| Shell access          | Shell available                     | No shell                                                   |
| Package manager       | `apk` (Alpine) or `apt` (Ubuntu)    | No package manager                                         |
| User                  | Runs as `root` or `nobody`          | Runs as `nonroot` user (UID 65532)                         |
| Build process         | Pre-compiled binaries               | Built from source with verified commit                     |
| Attack surface        | 200+ utilities and tools            | Only `grafana-agent-opeartor` binary and CA certificates   |
| Environment variables | `AGENT_DEPLOY_MODE=docker`          | Not set (intentionally omitted)                            |
| Debugging             | Shell and standard Unix tools       | Use Docker Debug or image mount for troubleshooting        |
| SBOM                  | Not included                        | Software Bill of Materials included                        |

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
- Application-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  dhi.io/grafana-agent:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

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

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                            |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the **Tags** tab for this repository. To view what packages are already installed in an image variant, select
   the **Tags** tab for this repository, and then select a tag.

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
