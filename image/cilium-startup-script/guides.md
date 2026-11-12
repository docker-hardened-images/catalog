## Prerequisites

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
repository**, and then follow the on-screen instructions.

## Start a startup-script instance

The cilium-startup-script image is designed to run as a DaemonSet in Kubernetes. It executes startup scripts on host
nodes using the privileged `nsenter` command. The script content is provided via the `STARTUP_SCRIPT` environment
variable.

Run the following command and replace <your-namespace> with your organization's namespace and <tag> with the image
variant you want to run.

```
docker run --rm --privileged --pid=host \
  -e STARTUP_SCRIPT='#!/bin/bash
echo "Hello from host namespace"' \
  <your-namespace>/dhi-cilium-startup-script:<tag>
```

## Common startup-script use cases

### Kubernetes DaemonSet deployment

Deploy as a DaemonSet to execute startup scripts on all nodes in a Kubernetes cluster.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: startup-script
  labels:
    app: startup-script
spec:
  selector:
    matchLabels:
      app: startup-script
  template:
    metadata:
      labels:
        app: startup-script
    spec:
      hostPID: true
      containers:
        - name: startup-script
          image: <your-namespace>/dhi-cilium-startup-script:<tag>
          securityContext:
            privileged: true
          env:
            - name: STARTUP_SCRIPT
              value: |
                #!/bin/bash
                set -o errexit
                set -o pipefail
                set -o nounset

                # Your startup commands here
                echo "Initializing node..."
```

### Node configuration and setup

Execute one-time configuration on Kubernetes nodes, with automatic checkpoint-based idempotency.

```yaml
env:
  - name: STARTUP_SCRIPT
    value: |
      #!/bin/bash
      # Configure system settings
      sysctl -w net.ipv4.ip_forward=1

      # Install or configure node-level components
      echo "Node setup complete"
  - name: CHECKPOINT_PATH
    value: /tmp/node-configured
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Cilium startup-script (Alpine)      | Docker Hardened startup-script                      |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Alpine-based minimal image          | Debian-based hardened with security patches         |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apk available                       | No package manager in runtime variants              |
| User            | Runs as root (required for nsenter) | Runs as nonroot user (root in dev variants)         |
| Attack surface  | Minimal Alpine base                 | Hardened Debian base                                |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

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
docker run --rm -it --pid container:my-image \
  --mount=type=image,source=<your-namespace>/dhi-busybox,destination=/dbg,ro \
  <your-namespace>/<image-name>:<tag> /dbg/bin/sh
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

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item                                                                         | Migration note                                                  |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Base image                                                                   | Replace your base images in your Dockerfile with a Docker       |
| Hardened Image.                                                              |                                                                 |
| Package management                                                           | Non-dev images, intended for runtime, don't contain             |
| package managers. Use package managers only in images with a dev tag.        |                                                                 |
| Non-root user                                                                | By default, non-dev images, intended for runtime, run as        |
| the nonroot user. Ensure that necessary files and directories are accessible |                                                                 |
| to the nonroot user.                                                         |                                                                 |
| Multi-stage build                                                            | Utilize images with a dev tag for build stages and              |
| non-dev images for runtime. For binary executables, use a static image for   |                                                                 |
| runtime.                                                                     |                                                                 |
| TLS certificates                                                             | Docker Hardened Images contain standard TLS certificates        |
| by default. There is no need to install TLS certificates.                    |                                                                 |
| Ports                                                                        | Non-dev hardened images run as a nonroot user by default. As a  |
| result, applications in these images can't bind to privileged ports          |                                                                 |
| (below 1024) when running in Kubernetes or in Docker Engine versions older   |                                                                 |
| than 20.10. Redis default port 6379 works without issues.                    |                                                                 |
| Entry point                                                                  | Docker Hardened Images may have different entry points than     |
| images such as Docker Official Images. Inspect entry points for Docker       |                                                                 |
| Hardened Images and update your Dockerfile if necessary.                     |                                                                 |
| No shell                                                                     | By default, non-dev images, intended for runtime, don't contain |
| a shell. Use dev images in build stages to run shell commands and then copy  |                                                                 |
| artifacts to the runtime stage.                                              |                                                                 |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

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
