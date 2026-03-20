## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-ebs-csi-driver:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-ebs-csi-driver:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start an AWS EBS CSI Driver image

The AWS EBS CSI Driver provides Container Storage Interface (CSI) support for Amazon EBS volumes in Kubernetes clusters.
It enables dynamic and static provisioning, volume snapshots, and volume resizing. The driver runs as two components: a
**controller** (handles volume create/delete/snapshot operations) and a **node plugin** (handles volume attach/mount on
each node).

### Basic usage

```bash
$ docker run --rm dhi.io/aws-ebs-csi-driver:<tag> --version
```

### Deployment in Kubernetes

The recommended way to deploy the AWS EBS CSI Driver is using the official Helm chart, which simplifies configuration
and management of the driver components.

#### Prerequisites: Configure IAM Permissions

The AWS EBS CSI Driver requires IAM permissions to manage EBS volumes. Configure IAM Roles for Service Accounts (IRSA)
or EKS Pod Identities **before** deploying the driver.

**For IRSA (IAM Roles for Service Accounts):**

1. Create an IAM role and attach the required policy. The minimum policy for that role is `AmazonEBSCSIDriverPolicy`.
   See the
   [AWS EBS CSI Driver installation guide](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md#set-up-driver-permissions)
   for detailed instructions.

1. Note the IAM role ARN (e.g., `arn:aws:iam::ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole`) - you'll need it during
   Helm installation.

1. If you have the hardened image mirrored to AWS ECR, ensure your nodes have the `AmazonEC2ContainerRegistryPullOnly`,
   usually AWS-managed nodegroups have that policy attached so they can pull images from your ECR repository. Otherwise
   you will need to specify the ImagePullSecrets value as mentioned further in this guide.

#### Deploy with Helm Chart

> **Note**: If you're using Amazon EKS, AWS provides a managed EBS CSI Driver add-on. However, **EKS add-ons do not
> support custom image overrides**. To use Docker Hardened Images, you must deploy the driver using Helm instead of the
> EKS add-on. The Helm chart provides full control over image selection and configuration.

If you've already installed the add-on, ensure no production workloads are using the existing CSI driver, afterwards,
you can remove it with:

```bash
eksctl delete addon --name aws-ebs-csi-driver --cluster <cluster-name>
# or via AWS Console: EKS → Add-ons → Delete
```

1. **Add the Helm repository:**

```bash
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
```

2. **Install the driver with Docker Hardened Images:**

If you configured IRSA, include the service account annotations, ensure you have the required ImagePullSecret and other
[values](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/charts/aws-ebs-csi-driver/values.yaml) you
might want to customize.

> **Note** If you are using the FIPS version, you might be interested into setting `fips: true`

```bash
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.annotations="eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole" \
  --set node.serviceAccount.annotations="eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole" \
  --set imagePullSecrets[0].name=dhi-secret \
  --set image.repository=dhi.io/aws-ebs-csi-driver \
  --set image.tag=<tag> # \
  # --set fips=true ## only in fips mode!
```

If you're using EKS Pod Identities or instance profiles, omit the service account annotations:

```bash
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set image.repository=dhi.io/aws-ebs-csi-driver \
  --set image.tag=<tag>
```

3. **Verify the deployment:**

```bash
kubectl get pod -n kube-system -l "app.kubernetes.io/name=aws-ebs-csi-driver,app.kubernetes.io/instance=aws-ebs-csi-driver"
```

## Runtime Requirements

The AWS EBS CSI Driver has different runtime requirements for its controller and node components:

### Controller Component

The controller component handles volume lifecycle operations (create, delete, snapshot) and requires:

- **IAM Permissions**: The service account must have IAM permissions to create, attach, detach, and delete EBS volumes.
  Use IAM Roles for Service Accounts (IRSA) or EKS Pod Identities for authentication.
- **No Privileged Access**: The controller does not require privileged mode or special capabilities.
- **Network Access**: Must be able to communicate with the Kubernetes API server and AWS EBS API.

### Node Component

The node component handles volume attachment and mounting on each Kubernetes node and requires:

- **Privileged Mode**: Must run with `privileged: true` or equivalent capabilities (`SYS_ADMIN`, `MOUNT`, etc.) to mount
  volumes on the host filesystem.
- **Mount Propagation**: Requires `Bidirectional` mount propagation to propagate mounts from the container to the host
  and vice versa.
- **Host Path Access**: Must have access to:
  - `/var/lib/kubelet` - Kubelet directory for pod volume mounts
  - `/var/lib/kubelet/plugins/ebs.csi.aws.com` - CSI plugin socket directory
  - `/dev` - Device directory for block device access
- **Node Compatibility**: Can only run on Amazon EC2 instances (not Fargate). EBS volumes cannot be mounted to Fargate
  pods.

## Common AWS EBS CSI Driver use cases

### Dynamic Volume Provisioning

Create a StorageClass for dynamic volume provisioning:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

Then you can create a pod with

```sh
# Persistent volume claim
kubectl apply -f - << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-sc
  resources:
    requests:
      storage: 5Gi
EOF

# pod that will consume the PVC and allocate a new EBS disk
kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: ebs-test-pod
spec:
  containers:
    - name: app
      image: busybox
      command:
        [
          "/bin/sh",
          "-c",
          "echo 'EBS test successful' > /data/test.txt && sleep 3600",
        ]
      volumeMounts:
        - name: ebs-volume
          mountPath: /data
  volumes:
    - name: ebs-volume
      persistentVolumeClaim:
        claimName: ebs-pvc
EOF
```

At this point, you should see the PV with a `ProvisioningSucceeded` event containing a message like
`Successfully provisioned volume pvc-<uuid>`

### Volume Snapshots

For volume snapshots, the specific CRDs should be installed before deploying the VolumeSnapshot object:
https://github.com/kubernetes-csi/external-snapshotter#usage

After installing it, they can be created with:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: ebs-snapshot
spec:
  source:
    persistentVolumeClaimName: ebs-pvc
  volumeSnapshotClassName: ebs-snapshot-class
```

### Static Volume Provisioning

You can also use the driver to mount existing EBS volumes:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ebs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: vol-0123456789abcdef0
    fsType: ext4
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
