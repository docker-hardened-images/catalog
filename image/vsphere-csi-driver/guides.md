## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/vsphere-csi-driver:<tag>`
- Mirrored image: `<your-namespace>/dhi-vsphere-csi-driver:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this vSphere CSI Driver image

This Docker Hardened Image includes the vSphere CSI driver binary (`vsphere-csi`) from the
[vsphere-csi-driver](https://github.com/kubernetes-sigs/vsphere-csi-driver) project, the component upstream publishes as
`registry.k8s.io/csi-vsphere/driver`. The same binary serves both roles in a deployment: the CSI controller plugin (in
the `vsphere-csi-controller` Deployment) and the CSI node plugin (in the `vsphere-csi-node` DaemonSet). The image also
ships the filesystem tooling the node plugin execs when formatting, mounting, and resizing volumes: mount and util-linux
(`mount`, `umount`, `blkid`, `lsblk`), e2fsprogs (`mkfs.ext4`, `e2fsck`, `resize2fs`), xfsprogs (`mkfs.xfs`,
`xfs_growfs`), and nfs-common (`mount.nfs`).

The metadata syncer is a separate image (`dhi.io/vsphere-csi-syncer`), and the sig-storage sidecars (attacher,
provisioner, resizer, snapshotter, node-driver-registrar, livenessprobe) are separate upstream components.

### Run the vSphere CSI Driver container

The driver is designed to run inside a Kubernetes cluster with in-cluster configuration and a vSphere connection
configuration. It is not intended to be used as a standalone `docker run` process for production workloads.

To verify the image is accessible and check the packaged version, run:

```bash
docker run --rm dhi.io/vsphere-csi-driver:<tag> --version
```

Configuration is environment-driven: `CSI_ENDPOINT` selects the CSI socket, `X_CSI_MODE` selects `controller` or `node`,
and `VSPHERE_CSI_CONFIG` points at the vSphere connection configuration (default `/etc/cloud/csi-vsphere.conf`). The
health endpoint listens on port 9808 and controller metrics on port 2112.

### Deploy in Kubernetes

Deploy with the upstream manifests for the packaged version, substituting the driver and syncer images with the hardened
images:

```bash
curl -LO https://raw.githubusercontent.com/kubernetes-sigs/vsphere-csi-driver/v<VERSION>/manifests/vanilla/vsphere-csi-driver.yaml
sed -i -e 's|registry.k8s.io/csi-vsphere/driver:v<VERSION>|dhi.io/vsphere-csi-driver:<tag>|g' \
  -e 's|registry.k8s.io/csi-vsphere/syncer:v<VERSION>|dhi.io/vsphere-csi-syncer:<tag>|g' \
  -e 's|gcr.io/cloud-provider-vsphere/csi/release/driver:v<VERSION>|dhi.io/vsphere-csi-driver:<tag>|g' \
  -e 's|gcr.io/cloud-provider-vsphere/csi/release/syncer:v<VERSION>|dhi.io/vsphere-csi-syncer:<tag>|g' \
  vsphere-csi-driver.yaml
kubectl apply -f vsphere-csi-driver.yaml
```

One adjustment is required for the node DaemonSet: the upstream manifests rely on the upstream image running as root,
while this hardened image runs as the nonroot user (65532) by default. Extend the existing security context of the
`vsphere-csi-node` container (upstream sets `privileged: true`, the `SYS_ADMIN` capability, and
`allowPrivilegeEscalation: true`) so the node plugin can mount and format volumes:

```yaml
securityContext:
  privileged: true
  runAsUser: 0
  runAsNonRoot: false
```

The controller Deployment needs no changes; upstream already runs the controller containers as user 65532.

Verify the controller and node pods are running:

```bash
kubectl -n vmware-system-csi get pods
```

For the vSphere connection secret, storage class setup, and the full installation flow, refer to the official
documentation at https://docs.vmware.com/en/VMware-vSphere-Container-Storage-Plug-in/index.html.

## FIPS variant

This image includes a FIPS-compliant variant that uses Go's native FIPS 140 cryptographic mode. The FIPS variant is
available with the `fips` tag suffix.

Use the FIPS variant when your deployment environment requires FIPS 140-compliant cryptographic operations. The FIPS
module is selected at build time, so the binaries run in Go's lenient FIPS mode (`fips140=on`) by default rather than
strict mode (`fips140=only`). Lenient mode is required because the driver's connections to the Kubernetes API server and
to vCenter negotiate X25519 (not FIPS-approved); strict mode would reject them. FIPS-approved algorithms are still
enforced for all other cryptographic operations.

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
