## Prerequisites

- Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
  organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
  repository**, and then follow the on-screen instructions.
- To use the code snippets in this guide, replace `<your-namespace>` with your organization's namespace, `<main-tag>`
  with the main `amazon-k8s-cni` image tag, and `<init-tag>` with the `amazon-k8s-cni-init` image tag.
- This image is designed for use on **AWS EKS clusters only**. It requires the AWS VPC CNI infrastructure, including IAM
  permissions for ENI management and access to the AWS EC2 metadata service.

## What's included in this amazon-k8s-cni image

- `aws-vpc-cni` — Main image entrypoint that bootstraps the `aws-node` container and starts the VPC CNI components
- `aws-cni` — Binary invoked by kubelet on every pod creation and deletion to physically wire up or tear down a pod's
  network namespace
- `aws-k8s-agent` — IPAMD daemon that maintains a warm pool of pre-allocated VPC IP addresses by managing ENI attachment
  and IP assignment on the node
- `egress-cni` — CNI plugin that gives pods the ability to reach endpoints via SNAT
- `grpc-health-probe` — Binary used as a Kubernetes exec liveness/readiness probe
- `/app/10-aws.conflist` — CNI configuration file defining the plugin chain
- `/app/eni-max-pods.txt` — Node-type to maximum pod count mapping used by the IPAMD daemon

## Deploy the amazon-k8s-cni image

The amazon-k8s-cni image runs as a **DaemonSet** on each node in your AWS EKS cluster. It cannot be run standalone — it
requires AWS infrastructure and a running EKS cluster.

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

### Deploy with Helm (recommended)

The official [eks-charts](https://github.com/aws/eks-charts) Helm chart for `aws-vpc-cni` supports overriding the image.
Replace `<your-namespace>` with your mirrored image namespace. Use the main `amazon-k8s-cni` image for the `aws-node`
container and the separate `amazon-k8s-cni-init` image for the init container.

```console
$ helm repo add eks https://aws.github.io/eks-charts
$ helm repo update
$ helm upgrade --install aws-vpc-cni eks/aws-vpc-cni \
  --namespace kube-system \
  --set image.overrideRepository=<your-namespace>/dhi-amazon-k8s-cni \
  --set image.tag=<main-tag> \
  --set init.image.overrideRepository=<your-namespace>/dhi-amazon-k8s-cni-init \
  --set init.image.tag=<init-tag> \
  --set imagePullSecrets[0].name=<secret-name>
```

Keep the upstream split: `image` is the main `aws-node` container image, and `init.image` is the init container image
that copies the CNI payload to the host.

### Deploy with kubectl

If you manage the VPC CNI DaemonSet directly, update the image references in your existing DaemonSet manifest. The
relevant containers to update are:

```yaml
# Init container — copies CNI binaries to the node host
initContainers:
- name: aws-vpc-cni-init
  image: <your-namespace>/dhi-amazon-k8s-cni-init:<init-tag>
  # default entrypoint /init/aws-vpc-cni-init is used

# Main container — runs the IPAMD daemon
containers:
- name: aws-node
  image: <your-namespace>/dhi-amazon-k8s-cni:<main-tag>
  # default entrypoint /app/aws-vpc-cni is used
```

Preserve the upstream Kubernetes security settings when switching images. Although the DHI runtime image defaults to a
nonroot user, the `aws-node` DaemonSet still needs the same privileged/root security context and hostPath mounts that
the upstream deployment expects.

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
