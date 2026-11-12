## How to use this image

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
repository**, and then follow the on-screen instructions.

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Deploy Calico CSI in Kubernetes

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

Calico CSI runs as a DaemonSet container on each Kubernetes node. The Tigera Operator deploys and manages it as part of
a full Calico stack. This image is not a standalone application and is intended to run alongside other Calico
components, including the node-driver-registrar sidecar.

Replace `<your-namespace>` with your organization's namespace, `<secret name>` with your Kubernetes image pull secret,
and `<tag>` with the image variant you want to use.

The Tigera Operator manages all Calico components. To use hardened images, configure the `Installation` custom resource
with your DHI registry settings (`registry`, `imagePath`, and `imagePrefix`). See the
[Calico Kube Controllers guides](../calico-kube-controllers/guides.md) for the same Installation CR pattern and Helm
install steps; they apply to Calico CSI and every other Calico component image.

**Note**: If you only have the Calico CSI DHI image available, other Calico components may fail to start with
`ImagePullBackOff` until their DHI images are also mirrored.

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
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. The Calico CSI entry point is `/usr/bin/csi-driver`, matching upstream `quay.io/calico/csi`.                                     |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

When deploying with the Tigera Operator, configure the `Installation` CR so the operator pulls `dhi/calico-csi` (and
other Calico DHI images) instead of upstream `quay.io/calico/*` references. See
[Calico Kube Controllers guides](../calico-kube-controllers/guides.md) for the Installation CR fields.

## Troubleshooting migration

### Image pull errors

If pods fail with `ImagePullBackOff`, verify that you have mirrored the image to your registry and configured the
`Installation` CR with the correct `registry`, `imagePath`, and `imagePrefix` values. Also confirm that your cluster has
a valid image pull secret for the mirrored registry.

### CSI driver not starting

The Calico CSI driver expects to run with elevated privileges and access to host paths such as `/var/lib/kubelet` and
`/var/run`. Ensure your DaemonSet manifest matches the upstream Calico CSI deployment requirements, including volume
mounts and `securityContext.privileged: true`.

### Permission denied

Runtime images run as the `nonroot` user. If the CSI driver cannot access required host-mounted directories, verify that
volume mount permissions and security contexts match the upstream Calico CSI DaemonSet configuration.
