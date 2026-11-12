## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this amazon-k8s-cni-init image

- `/init/aws-vpc-cni-init` - Init container entrypoint that copies CNI artifacts to the host CNI bin directory and then
  performs node-level network setup required by the Amazon VPC CNI plugin.
- `/init/aws-cni-support.sh` - Support script from `awslabs/amazon-eks-ami` used for collecting diagnostic information
  when troubleshooting node networking issues.
- Core CNI plugin binaries staged into `/init/` and then copied to the host by the init container: `bridge`, `dummy`,
  `host-device`, `ipvlan`, `loopback`, `macvlan`, `ptp`, `vlan`, `dhcp`, `host-local`, `static`, `bandwidth`,
  `firewall`, `portmap`, `sbr`, and `tuning`.

## Guidance for using this image

This image is designed to be used as the `aws-vpc-cni-init` **init container** in the Amazon VPC CNI DaemonSet, not as a
standalone workload. Its job is to run once on each node, copy the CNI binaries into the host CNI bin directory, and
perform the node-level setup that the main `amazon-k8s-cni` container depends on afterward.

When deploying this image, follow the upstream VPC CNI configuration for the init container:

- Mount the host CNI bin directory at `/host/opt/cni/bin` so the init container can copy the staged binaries onto the
  node.
- Run the init container with `securityContext.privileged: true`. In upstream Amazon VPC CNI, the rendered manifest for
  `aws-vpc-cni-init` sets `privileged: true`, and the upstream Helm chart defaults `init.securityContext.privileged` to
  `true`.
- Preserve root execution for the init container. Upstream gets this implicitly from its root-based image, but the DHI
  runtime image defaults to the `nonroot` user. If your deployment sets an explicit container user, configure the init
  container to run as root, for example with `securityContext.runAsUser: 0`.
- Keep this image paired with the main `amazon-k8s-cni` image in the same DaemonSet. The init image prepares the host;
  the main image runs the long-lived IPAMD and CNI agent processes.

For upstream reference, see the Amazon VPC CNI rendered manifest and Helm chart defaults:

- Rendered manifest:
  [`config/master/aws-k8s-cni.yaml`](https://github.com/aws/amazon-vpc-cni-k8s/blob/v1.21.1/config/master/aws-k8s-cni.yaml)
- Helm chart defaults:
  [`charts/aws-vpc-cni/values.yaml`](https://github.com/aws/amazon-vpc-cni-k8s/blob/v1.21.1/charts/aws-vpc-cni/values.yaml)

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
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy any necessary artifacts to the runtime stage.                                                                                                                                    |

The following steps outline the general migration process.

1. Find hardened images for your app.
1. Update the base image in your Dockerfile.
1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.
1. Install additional packages.

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers.

### Permissions

By default image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
