## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-efs-csi-driver:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-efs-csi-driver:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Deploy the AWS EFS CSI Driver

The AWS EFS CSI Driver is a Kubernetes-native component deployed as a DaemonSet (node plugin) and Deployment
(controller). It is not intended to be run as a standalone container. The recommended deployment method is via the
official Helm chart, using the DHI image as a drop-in replacement for the upstream image.

### Prerequisites

Before deploying the driver, ensure you have:

- A running Kubernetes cluster (EKS or self-managed on AWS EC2)
- An existing Amazon EFS file system in the same AWS region and VPC as your cluster
- IAM permissions configured for the driver (see [IAM permissions](#iam-permissions) below)
- Helm v3 or later installed

### IAM permissions

The driver requires IAM permissions to manage EFS access points and describe file systems. Create an IAM policy with the
following permissions and attach it to your cluster nodes or use IAM Roles for Service Accounts (IRSA):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:DescribeFileSystems",
        "elasticfilesystem:DescribeMountTargets",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:CreateAccessPoint"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:TagResource"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "elasticfilesystem:DeleteAccessPoint",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}
```

### Deploy with Helm

Add the Helm repository and install the driver, overriding the image to use the DHI image:

```bash
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update aws-efs-csi-driver

helm upgrade --install aws-efs-csi-driver \
  --namespace kube-system \
  aws-efs-csi-driver/aws-efs-csi-driver \
  --set image.repository=dhi.io/aws-efs-csi-driver \
  --set image.tag=2
```

To use a mirrored image from your own registry:

```bash
helm upgrade --install aws-efs-csi-driver \
  --namespace kube-system \
  aws-efs-csi-driver/aws-efs-csi-driver \
  --set image.repository=<your-namespace>/dhi-aws-efs-csi-driver \
  --set image.tag=2
```

To use IRSA (IAM Roles for Service Accounts) with a pre-created service account:

```bash
helm upgrade --install aws-efs-csi-driver \
  --namespace kube-system \
  aws-efs-csi-driver/aws-efs-csi-driver \
  --set image.repository=dhi.io/aws-efs-csi-driver \
  --set image.tag=2 \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=efs-csi-controller-sa
```

## Common AWS EFS CSI Driver use cases

### Static provisioning

Static provisioning lets you mount an existing EFS file system as a Kubernetes PersistentVolume. You must create the EFS
file system in AWS first, then reference its file system ID in the PersistentVolume manifest.

Create a StorageClass, PersistentVolume, and PersistentVolumeClaim:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: efs-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  persistentVolumeReclaimPolicy: Retain
  csi:
    driver: efs.csi.aws.com
    volumeHandle: fs-0123456789abcdef0   # Replace with your EFS file system ID
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
```

Apply the manifests and use the PVC in a Pod:

```bash
kubectl apply -f efs-static.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: efs-app
spec:
  containers:
    - name: app
      image: busybox
      command: ["/bin/sh"]
      args: ["-c", "while true; do echo $(date -u) >> /data/out; sleep 5; done"]
      volumeMounts:
        - name: persistent-storage
          mountPath: /data
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: efs-claim
```

### Dynamic provisioning

Dynamic provisioning automatically creates an EFS Access Point for each PersistentVolumeClaim. You must create the EFS
file system in AWS first and provide its ID in the StorageClass parameters.

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-0123456789abcdef0   # Replace with your EFS file system ID
  directoryPerms: "700"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
  basePath: "/dynamic_provisioning"
  subPathPattern: "${.PVC.namespace}/${.PVC.name}"
  ensureUniqueDirectory: "true"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
```

### Using the FIPS variant

The `2-fips` tag provides a FIPS 140-validated build of the AWS EFS CSI Driver. Use this variant in environments that
require FIPS-compliant cryptographic operations, such as US federal government workloads.

The FIPS variant sets `GODEBUG=fips140=only`, which enforces strict FIPS mode — any use of non-FIPS-approved algorithms
causes a runtime panic. It also sets `GOFIPS140=v1.0.0` to use the validated Go FIPS module.

Deploy the FIPS variant with Helm:

```bash
helm upgrade --install aws-efs-csi-driver \
  --namespace kube-system \
  aws-efs-csi-driver/aws-efs-csi-driver \
  --set image.repository=dhi.io/aws-efs-csi-driver \
  --set image.tag=2-fips \
  --set useFIPS=true
```

The `--set useFIPS=true` Helm parameter instructs the driver to use FIPS endpoints for AWS API calls
(`AWS_USE_FIPS_ENDPOINT=true`). FIPS endpoints are only available in US and Canada AWS regions. Do not set
`useFIPS=true` in regions without FIPS endpoint support, as this will cause invalid endpoint errors.

## Non-hardened images vs. Docker Hardened Images

The following table summarizes the key differences between the upstream
`public.ecr.aws/efs-csi-driver/amazon/aws-efs-csi-driver` image and this Docker Hardened Image.

| Feature                | Upstream image                     | Docker Hardened Image        |
| :--------------------- | :--------------------------------- | :--------------------------- |
| Base OS                | Amazon Linux 2023 (minimal)        | Debian 13 (static base)      |
| Run user               | root (uid 0)                       | nonroot (uid 65532)          |
| `amazon-efs-utils`     | Included (Amazon Linux RPM)        | Not included                 |
| Python / botocore      | Included (for cross-account mount) | Not included                 |
| `stunnel`              | Included                           | Included (`stunnel4`)        |
| `mount` / `mount.nfs4` | Included                           | Included                     |
| EFS config directory   | `/etc/amazon/efs-static-files`     | Not present                  |
| FIPS variant           | Via `useFIPS=true` Helm flag       | Dedicated `2-fips` image tag |

### amazon-efs-utils not included

The upstream image bundles `amazon-efs-utils`, an Amazon Linux-specific package that provides the `mount.efs` helper
script. This helper orchestrates TLS encryption in transit by managing stunnel connections and EFS-specific
configuration files under `/etc/amazon/efs/`.

The DHI image is built on Debian 13 and `amazon-efs-utils` is not available in Debian package repositories. The DHI
image includes `stunnel4`, `mount`, and `mount.nfs4` (from `nfs-common`) directly, which are the underlying tools that
`amazon-efs-utils` depends on.

**Impact**: EFS mounts that rely on the `mount.efs` helper for TLS encryption in transit will not work with the DHI
image. Standard NFS4 mounts (without TLS) are fully supported. If your workload requires encryption in transit via the
EFS mount helper, use the upstream Amazon Linux-based image for the node plugin component.

### Cross-account EFS mounts not supported

The upstream image includes Python 3.11 and the `botocore` library, which `amazon-efs-utils` uses to support
cross-account EFS mounts. Since neither `amazon-efs-utils` nor Python is included in the DHI image, cross-account EFS
mounts are not supported.

### Run user and Kubernetes security context

The DHI image defaults to running as `nonroot` (uid 65532). However, the official Helm chart sets
`securityContext.runAsUser: 0` for both the controller and node pods, which overrides the image's default user. When
deploying via Helm with default values, the driver runs as root as required for filesystem mount operations.

If you deploy the driver using custom manifests without the Helm chart's security context overrides, add the following
to your pod spec to ensure the driver can perform mount operations:

```yaml
securityContext:
  runAsUser: 0
  runAsGroup: 0
  fsGroup: 0
```

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
