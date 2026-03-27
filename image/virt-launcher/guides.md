## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this virt-launcher image

This Docker Hardened Virt Launcher image is a component of the [KubeVirt](https://github.com/kubevirt/kubevirt) project.

- `virt-launcher`: Virt Launcher provides the runtime environment for virtual machines in KubeVirt

KubeVirt extends Kubernetes with virtualization capabilities. The virt-launcher is one of several KubeVirt components
typically deployed by the KubeVirt operator as part of a full installation.

### Run the virt-launcher container

The Virt Launcher is designed to run within a Kubernetes cluster as part of the KubeVirt operator deployment.

To display help information:

```bash
docker run --rm dhi.io/virt-launcher:<tag> --help
```

Verify the deployed version by inspecting the running KubeVirt pods in your cluster:

```bash
kubectl get pods -n kubevirt -l kubevirt.io=virt-launcher -o jsonpath='{.items[*].spec.containers[*].image}'
```

### Deploy KubeVirt in Kubernetes

The recommended way to deploy KubeVirt (including virt-launcher) is using the official KubeVirt operator manifests.
Replace `<version>` with the KubeVirt release you intend to run (it should match the virt-launcher version you are
standardizing on).

1. Install the KubeVirt operator:

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/<version>/kubevirt-operator.yaml
```

2. Create the KubeVirt custom resource:

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/<version>/kubevirt-cr.yaml
```

3. Verify the deployment:

```bash
kubectl get pods -n kubevirt
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Available image tags for virt-launcher:**

| Variant Type          | Tag Examples                             | Description                         |
| --------------------- | ---------------------------------------- | ----------------------------------- |
| **Standard (Debian)** | `<version>`, `<major>`                   | Runtime variants for production use |
|                       | `<version>-debian13`, `<major>-debian13` | Explicit Debian base specification  |

**Tag selection guidance:**

- Use `dhi.io/virt-launcher:<version>` for standard production deployments
- Use major version tags (like `:<major>`) for automatic minor updates (not recommended for production)

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

FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
validated under FIPS 140, a U.S. government standard for secure cryptographic operations.

**Runtime requirements specific to FIPS:**

- FIPS mode restricts cryptographic operations to FIPS-validated algorithms
- Usage of non-compliant operations (like MD5) will fail
- Larger image size due to FIPS-validated cryptographic libraries

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

   For Debian-based images, you can use apt-get to install packages.

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
