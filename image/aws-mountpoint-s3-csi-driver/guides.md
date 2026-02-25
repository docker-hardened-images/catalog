## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-mountpoint-s3-csi-driver:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-mountpoint-s3-csi-driver:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this image

This Docker Hardened AWS Mountpoint S3 CSI Driver image includes:

- `/usr/bin/aws-s3-csi-driver` - Main CSI driver (node plugin)
- `/usr/bin/aws-s3-csi-controller` - Controller component for managing Mountpoint Pods
- `/usr/bin/aws-s3-csi-mounter` - Mounter binary that runs inside Mountpoint Pods
- `/usr/bin/mount-s3` - Mountpoint for Amazon S3 binary (FUSE client)

## Start an AWS Mountpoint S3 CSI Driver image

The AWS Mountpoint for Amazon S3 CSI Driver enables Kubernetes applications to access S3 buckets through a file system
interface. Unlike block storage CSI drivers, this driver mounts S3 buckets (object storage) as volumes using FUSE.

### Basic usage

```bash
$ docker run --rm dhi.io/aws-mountpoint-s3-csi-driver:<tag> --version
```

### Deployment in Kubernetes

The recommended way to deploy the AWS Mountpoint S3 CSI Driver is using the official Helm chart.

#### Prerequisites: Configure IAM Permissions

The driver requires IAM permissions to access S3 buckets. Configure IAM Roles for Service Accounts (IRSA) or EKS Pod
Identities **before** deploying the driver.

**For IRSA (IAM Roles for Service Accounts):**

1. Create an IAM role with S3 permissions. See the
   [Mountpoint S3 CSI Driver IAM setup guide](https://github.com/awslabs/mountpoint-s3-csi-driver/blob/main/docs/install.md#configure-access-to-s3)
   for the required policy.

1. Note the IAM role ARN - you'll need it during Helm installation.

#### Deploy with Helm Chart

> **Note**: If you're using Amazon EKS, AWS provides a managed Mountpoint S3 CSI Driver add-on. However, **EKS add-ons
> do not support custom image overrides**. To use Docker Hardened Images, you must deploy the driver using Helm instead
> of the EKS add-on.

If you've already installed the add-on:

```bash
eksctl delete addon --name aws-mountpoint-s3-csi-driver --cluster <cluster-name>
# or via AWS Console: EKS → Add-ons → Delete
```

1. **Add the Helm repository:**

```bash
helm repo add aws-mountpoint-s3-csi-driver https://awslabs.github.io/mountpoint-s3-csi-driver
helm repo update
```

2. **Install the driver with Docker Hardened Images:**

```bash
helm install aws-mountpoint-s3-csi-driver aws-mountpoint-s3-csi-driver/aws-mountpoint-s3-csi-driver \
  --namespace kube-system \
  --set node.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::ACCOUNT_ID:role/S3CSIDriverRole" \
  --set imagePullSecrets[0].name=dhi-secret \
  --set image.repository=dhi.io/aws-mountpoint-s3-csi-driver \
  --set image.tag=<tag>
```

3. **Verify the deployment:**

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-mountpoint-s3-csi-driver
```

## Runtime Requirements

The AWS Mountpoint S3 CSI Driver has specific runtime requirements due to its FUSE-based architecture.

### Controller Component

The controller component manages Mountpoint Pods and requires:

- **IAM Permissions**: Service account must have permissions to access S3 buckets.
- **Cluster Access**: Must communicate with the Kubernetes API server to create/manage Mountpoint Pods.

### Node Component

The node component (DaemonSet) handles volume staging and requires:

- **Privileged Mode**: Required for FUSE mount operations.
- **Host Path Access**: Access to `/var/lib/kubelet` for pod volume mounts.

### Mountpoint Pods (v2 Architecture)

In v2, the actual `mount-s3` process runs in dedicated Mountpoint Pods (not on the host). This provides:

- Better isolation and security
- SELinux compatibility (ROSA support)
- Pod sharing for improved resource utilization

## Common use cases

### Mount an S3 Bucket (Static Provisioning)

The Mountpoint S3 CSI Driver supports **static provisioning only** - you must reference an existing S3 bucket.

1. **Create a PersistentVolume:**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-pv
spec:
  capacity:
    storage: 1200Gi # Ignored by S3, but required by Kubernetes
  accessModes:
    - ReadWriteMany
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-csi-driver-volume
    volumeAttributes:
      bucketName: my-s3-bucket
```

2. **Create a PersistentVolumeClaim:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: s3-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: "" # Empty for static provisioning
  resources:
    requests:
      storage: 1200Gi
  volumeName: s3-pv
```

3. **Use in a Pod:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: s3-app
spec:
  containers:
    - name: app
      image: busybox
      command: ["/bin/sh", "-c", "ls /data && sleep 3600"]
      volumeMounts:
        - name: s3-volume
          mountPath: /data
  volumes:
    - name: s3-volume
      persistentVolumeClaim:
        claimName: s3-pvc
```

### Mount with Specific Prefix

Mount only a specific prefix (folder) from the bucket:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-prefix-pv
spec:
  capacity:
    storage: 1200Gi
  accessModes:
    - ReadWriteMany
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-prefix-volume
    volumeAttributes:
      bucketName: my-s3-bucket
  mountOptions:
    - prefix=data/subfolder/
```

### Read-Only Mount

For workloads that only need to read from S3:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-readonly-pv
spec:
  capacity:
    storage: 1200Gi
  accessModes:
    - ReadOnlyMany
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-readonly-volume
    volumeAttributes:
      bucketName: my-s3-bucket
  mountOptions:
    - read-only
```

## Non-hardened images vs. Docker Hardened Images

This Docker Hardened Image differs from the upstream image in the following ways:

- **Base image**: Uses Debian 13 instead of the AWS EKS distro minimal base (Amazon Linux 2), which eliminates several
  CVEs present in the upstream image's OpenSSL and curl packages.
- **libfuse**: Uses Debian's maintained `libfuse2` package instead of the bundled 2018 version from Amazon Linux 2.
- **Go runtime**: Built with an updated Go toolchain that addresses known CVEs in the Go standard library.

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
  cryptographic operations.

### FIPS compliance details

The FIPS variants provide **FIPS-compliant cryptography for the CSI driver control plane** with the following
characteristics:

#### Compliance Summary

**FIPS-Compliant Components:**

- **CSI Driver Control Plane**: All Go-based CSI components (`aws-s3-csi-driver`, `aws-s3-csi-controller`,
  `aws-s3-csi-mounter`) use FIPS 140-3 validated cryptography
- **Data Transfer Security**: All S3 data transfers use TLS encryption to FIPS-compliant AWS endpoints
- **Cryptographic Operations**: Volume management, authentication, and control operations use FIPS-validated OpenSSL

**Non-FIPS Component:**

- **mount-s3 Binary**: The FUSE client uses AWS-LC (FIPS-validated library) but not built in FIPS mode

#### Component Details

| Component               | Language | FIPS Status                                        | Notes                                                     |
| :---------------------- | :------- | :------------------------------------------------- | :-------------------------------------------------------- |
| `aws-s3-csi-driver`     | Go       | FIPS-compliant                                     | Built with Go 1.25+ FIPS mode using OpenSSL FIPS provider |
| `aws-s3-csi-controller` | Go       | FIPS-compliant                                     | Built with Go 1.25+ FIPS mode using OpenSSL FIPS provider |
| `aws-s3-csi-mounter`    | Go       | FIPS-compliant                                     | Built with Go 1.25+ FIPS mode using OpenSSL FIPS provider |
| `mount-s3`              | Rust     | Uses FIPS-validated AWS-LC, not built in FIPS mode | See details below                                         |

**FIPS implementation:**

- Go binaries use `GODEBUG=fips140=only` with OpenSSL FIPS provider (3.1.2)
- OpenSSL FIPS module (3.5.5) provides FIPS 140-3 validated cryptography
- FIPS mode enforced at runtime via `GOFIPS140=v1.0.0`

#### Understanding mount-s3 FIPS Status

The `mount-s3` binary uses AWS-LC (AWS LibCrypto) for cryptography through the AWS Common Runtime (CRT). AWS-LC itself
has received
[FIPS 140-3, Level 1 certification](https://aws.amazon.com/blogs/security/aws-lc-is-now-fips-140-3-certified/)
(certificates #4631, #4759, #4816).

**Why isn't mount-s3 built in FIPS mode?**

The upstream mountpoint-s3 build explicitly disables the Go and Perl dependencies required for FIPS mode compilation to
reduce build complexity and binary size. Enabling FIPS would require upstream changes to the mountpoint-s3-crt-sys build
configuration.

**What this means in practice:**

- **Control plane operations** (volume creation, mounting, authentication) use FIPS-validated cryptography
- **All S3 data transfers** use TLS encryption to FIPS-compliant AWS endpoints
- **AWS-LC library** is the same FIPS-validated codebase used by AWS services
- **mount-s3 binary** uses AWS-LC but not compiled in FIPS mode

#### Regulatory Compliance Considerations

**This image meets FIPS requirements for most regulated environments because:**

1. **Control plane is fully FIPS-compliant**: All CSI driver operations (volume management, pod coordination,
   authentication) use FIPS 140-3 validated cryptography
1. **Data in transit is protected**: All S3 transfers use TLS to FIPS-compliant AWS endpoints
1. **Cryptographic library is FIPS-validated**: AWS-LC has NIST CMVP certification
1. **Industry-standard approach**: Similar to how many cloud services use FIPS-validated libraries

**When full FIPS mode for mount-s3 would be required:**

- Environments with strict requirements that ALL binaries must be built in FIPS mode
- Compliance frameworks that mandate FIPS mode compilation (not just FIPS-validated libraries)
- Organizations with policies requiring end-to-end FIPS mode enforcement

**For environments requiring full FIPS compliance:**

If your environment requires mount-s3 to be built in FIPS mode, consider:

1. Filing a feature request with the [upstream project](https://github.com/awslabs/mountpoint-s3-csi-driver) to add
   official FIPS build support
1. Contacting Docker support to discuss custom build options
1. Evaluating whether your compliance requirements are met by FIPS-compliant control plane and TLS-encrypted data
   transfers

**Note:** Most federal and regulated environments accept this configuration because the control plane uses
FIPS-validated cryptography and all data transfers are encrypted with FIPS-compliant TLS to AWS endpoints.

To view the image variants a tag.

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
