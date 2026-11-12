## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/azuredisk-csi:<tag>`
- Mirrored image: `<your-namespace>/dhi-azuredisk-csi:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Azure Disk CSI Driver image

This Docker Hardened Image includes the Azure Disk CSI driver binary (`azurediskplugin`) from the
[azuredisk-csi-driver](https://github.com/kubernetes-sigs/azuredisk-csi-driver) project, the component upstream
publishes as `mcr.microsoft.com/oss/v2/kubernetes-csi/azuredisk-csi`. The same binary serves both roles in a deployment:
the CSI controller plugin (in the `csi-azuredisk-controller` Deployment) and the CSI node plugin (in the
`csi-azuredisk-node` DaemonSet). The image also ships the filesystem tooling the node plugin execs when it formats,
mounts, checks and resizes disks: `mount`, `umount`, `blkid`, `findmnt`, `wipefs`, `blockdev` and `fsck` (util-linux),
`mkfs.ext4` and `resize2fs` (e2fsprogs), `mkfs.xfs` and `xfs_growfs` (xfsprogs), and `mkfs.btrfs` and `btrfs`
(btrfs-progs).

The sig-storage sidecars (`csi-provisioner`, `csi-attacher`, `csi-resizer`, `livenessprobe`,
`csi-node-driver-registrar`) are separate components and are not part of this image.

### Run the Azure Disk CSI Driver container

The driver is designed to run inside a Kubernetes cluster on Azure, using the cluster's cloud provider configuration. It
is not intended to be used as a standalone `docker run` process for production workloads.

To verify the image is accessible and check the packaged version, run:

```bash
docker run --rm dhi.io/azuredisk-csi:<tag> --version
```

### Deploy in Kubernetes

Deploy with the upstream Helm chart, pointing the driver image at the hardened image. The chart accepts a full image
repository when it does not start with `/`:

```bash
helm repo add azuredisk-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/charts
helm repo update azuredisk-csi-driver
helm install azuredisk-csi-driver azuredisk-csi-driver/azuredisk-csi-driver \
  --namespace kube-system \
  --version <chart-version> \
  --set image.azuredisk.repository=dhi.io/azuredisk-csi \
  --set image.azuredisk.tag=<tag> \
  --set windows.enabled=false \
  --set imagePullSecrets[0]=<pull-secret>
```

Use the newest chart in the same minor line as the image, for example `1.36.0` for the `1.36` image line. The hardened
images are Linux-only, so the example disables the chart's Windows node DaemonSet.

The upstream chart relies on the upstream image running as root, while this hardened image runs as the nonroot user
(65532) by default. The node plugin must run as root to mount and format disks, and the controller reads the cloud
provider configuration file from the host. After installing, set `runAsUser: 0` on the `azuredisk` container of both
workloads (the node container is already `privileged`, so only the user changes):

```bash
kubectl -n kube-system patch daemonset csi-azuredisk-node --patch \
  '{"spec":{"template":{"spec":{"containers":[{"name":"azuredisk","securityContext":{"runAsUser":0,"runAsNonRoot":false}}]}}}}'
kubectl -n kube-system patch deployment csi-azuredisk-controller --patch \
  '{"spec":{"template":{"spec":{"containers":[{"name":"azuredisk","securityContext":{"runAsUser":0,"runAsNonRoot":false}}]}}}}'
```

Verify the controller and node pods are running:

```bash
kubectl -n kube-system get pods -l app=csi-azuredisk-node
kubectl -n kube-system get pods -l app=csi-azuredisk-controller
```

For the cloud provider configuration, workload identity, storage classes and the full installation flow, refer to the
upstream documentation at https://github.com/kubernetes-sigs/azuredisk-csi-driver.

## FIPS variant

This image includes a FIPS-compliant variant that uses Go's native FIPS 140 cryptographic mode together with the OpenSSL
FIPS provider for operating-system level cryptography. The FIPS variant is available with the `fips` tag suffix.

Use the FIPS variant when your deployment environment requires FIPS 140-compliant cryptographic operations. The Go FIPS
module is selected at build time, so the driver runs in Go's lenient FIPS mode (`fips140=on`) by default rather than
strict mode (`fips140=only`).

## Non-hardened images vs. Docker Hardened Images

- The upstream image runs as root; this image runs as the nonroot user (65532). The node plugin must run as root to
  format and mount disks, so set `runAsUser: 0` on the `azuredisk` containers as shown in
  [Deploy in Kubernetes](#deploy-in-kubernetes).
- The upstream image includes a Bash shell and no Python. The Debian runtime images have neither. On Alpine, `coreutils`
  and `util-linux-misc` require `/bin/sh` and `xfsprogs-extra`, which ships `xfs_growfs`, requires `python3`, so the
  Alpine runtime images include a BusyBox shell and Python.
- On the Debian runtime images, the `fsck -a` that the driver runs before mounting an existing XFS or btrfs volume exits
  8, because Debian ships `fsck.xfs` and `fsck.btrfs` as shell scripts. Upstream those scripts exit 0 without checking
  anything, so no check is lost: the driver logs the failure, reports its `fsck_repair` metric as failed, and mounts the
  volume. ext4 volumes are checked normally.

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

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

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

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
