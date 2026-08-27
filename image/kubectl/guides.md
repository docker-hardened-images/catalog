## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a kubectl instance

The kubectl image provides the Kubernetes command-line tool for interacting with Kubernetes clusters. The default
entrypoint displays help information.

Run the following command and replace `<tag>` with the image variant you want to run.

```console
$ docker run --rm dhi.io/kubectl:<tag>
```

## Common kubectl use cases

### View cluster information

To connect kubectl to your Kubernetes cluster, mount your kubeconfig file and run kubectl commands:

```console
$ docker run --rm \
  --network host \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi.io/kubectl:<tag> \
  cluster-info
```

### List pods in a namespace

Check the status of pods in a specific namespace:

```console
$ docker run --rm \
  --network host \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi.io/kubectl:<tag> \
  get pods -n default
```

### Apply Kubernetes manifests

Deploy resources to your cluster by mounting a directory with Kubernetes manifests:

```console
$ docker run --rm \
  --network host \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  -v $(pwd)/manifests:/manifests:ro \
  dhi.io/kubectl:<tag> \
  apply -f /manifests/
```

### Use as a base image in CI/CD

The kubectl image is commonly used in CI/CD pipelines for deploying applications to Kubernetes:

```console
$ mkdir -p manifests

$ cat > manifests/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-config
  namespace: default
data:
  key: value
EOF

$ cat > Dockerfile << 'EOF'
FROM dhi.io/kubectl:<tag>
COPY manifests/ /manifests/
ENTRYPOINT ["/usr/local/bin/kubectl"]
CMD ["apply", "-f", "/manifests/"]
EOF

$ docker build -t my-kubectl-deploy .

$ docker run --rm \
  --network host \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  my-kubectl-deploy
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official kubectl             | Docker Hardened kubectl                             |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
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

```console
$ docker debug <container-name>
```

or mount debugging tools with the Image Mount feature. When using Image Mount, you must override the entrypoint since
the default entrypoint is kubectl. Choose a busybox image that matches your base OS:

| kubectl Base OS      | Use This Busybox Image                    |
| -------------------- | ----------------------------------------- |
| Alpine (`*-alpine*`) | `busybox:musl`                            |
| Debian (`*-debian*`) | `busybox:glibc` or `dhi.io/busybox:<tag>` |

For Alpine-based images:

```console
$ docker run --rm -it --pid container:<container-name> \
  --entrypoint /dbg/bin/sh \
  --mount=type=image,source=busybox:musl,destination=/dbg,ro \
  dhi.io/kubectl:<tag>
```

For Debian-based images:

```console
$ docker run --rm -it --pid container:<container-name> \
  --entrypoint /dbg/bin/sh \
  --mount=type=image,source=busybox:glibc,destination=/dbg,ro \
  dhi.io/kubectl:<tag>
```

> [!NOTE] The `--entrypoint /dbg/bin/sh` flag is required because the kubectl image's default entrypoint is
> `/usr/local/bin/kubectl`. Without this override, the shell path would be interpreted as a kubectl subcommand.

## Image variants

The kubectl Docker Hardened Images come in different variants depending on their intended use.

**Runtime variants** are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

**Build-time variants** typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

**FIPS variants** include `fips` in the variant name and provide FIPS 140-2 compliant cryptographic modules. These
images:

- Include OpenSSL with FIPS provider enabled
- Are available in both runtime and dev variants
- Meet compliance requirements for regulated environments

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                                                    |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

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

For the kubectl image, the entrypoint is `/usr/local/bin/kubectl`. This means any arguments passed to `docker run` are
interpreted as kubectl subcommands. To run a different command, use the `--entrypoint` flag.
