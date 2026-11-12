## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-controllers-k8s-eks-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-controllers-k8s-eks-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The controller is a Kubernetes operator, so the image is meant to run inside a cluster. To list its command-line flags,
run the image with `--help`:

```bash
$ docker run --rm dhi.io/aws-controllers-k8s-eks-controller:1.26.0-debian13 --help
```

## Install the controller with the upstream Helm chart

You need an Amazon EKS cluster, Helm 3, `kubectl` access to the cluster, and an IAM role that allows the controller to
manage EKS resources in the target AWS Region. The upstream chart is published as an OCI artifact at
`oci://public.ecr.aws/aws-controllers-k8s/eks-chart`. It installs the custom resource definitions, the controller
Deployment, the service account, and the RBAC rules. Override its image values to run this image.

```bash
$ helm install ack-eks oci://public.ecr.aws/aws-controllers-k8s/eks-chart \
  --version 1.26.0 \
  --namespace ack-system --create-namespace \
  --set image.repository=dhi.io/aws-controllers-k8s-eks-controller \
  --set image.tag=1.26.0-debian13 \
  --set aws.region=us-west-2
$ kubectl --namespace ack-system get pods
```

The chart installs the custom resource definitions for the `eks.services.k8s.aws/v1alpha1` API group. Create custom
resources only after the install finishes, because the API server rejects resources of a kind it does not know.

Cluster nodes must be able to pull from `dhi.io`. If they cannot, create a `docker-registry` secret for `dhi.io` in the
install namespace and reference it through the chart's image pull settings.

### Configure the AWS Region and credentials

The controller must know the AWS Region it manages. Set `aws.region` in the chart, as shown above, or pass the
`--aws-region` flag or the `AWS_REGION` environment variable to the container. Without a Region, the controller exits
with status 1 and logs `AWS region is missing`.

The controller reads credentials through the AWS SDK default credential chain. Use one of the following:

- IAM Roles for Service Accounts (IRSA): annotate the controller's service account with the IAM role ARN under the
  `eks.amazonaws.com/role-arn` key, using the chart's service account annotation settings.
- EKS Pod Identity: create a Pod Identity association for the controller's service account with
  `aws eks create-pod-identity-association`.
- A shared credentials file: mount the file at `/.aws/credentials`. The image runs as uid 65532 with home
  `/home/nonroot`, but `/home/nonroot/.aws` links to `/.aws`, so the SDK finds the file at its default path, as it does
  with upstream's image. To read the file from another path, set `AWS_SHARED_CREDENTIALS_FILE` to that path. You can
  also use the chart's credentials secret (`aws.credentials.secretName`).

IRSA or Pod Identity avoids storing long-lived keys in the cluster. Check the chart's `values.yaml` for the exact
setting names in your chart version.

### Ports

- `8080/tcp`: Prometheus metrics (`--metrics-addr`).
- `8081/tcp`: health probes on `/healthz` and `/readyz` (`--healthz-addr`).

The webhook server listens on port 9433 only when `--enable-webhook-server` is set. It is off by default, so the image
does not declare that port.

To check the readiness probe from your workstation, forward the port of a controller pod and request `/readyz`:

```bash
$ kubectl --namespace ack-system port-forward pod/<controller-pod> 8081:8081
$ curl -fsS http://127.0.0.1:8081/readyz
```

`curl -f` exits with a non-zero status on any response outside the 2xx range.

### User and root filesystem

The image runs as uid 65532. The upstream image runs as uid 1000. The upstream chart sets `runAsNonRoot` and does not
set `runAsUser`, so its default values work without change. If you set `runAsUser` yourself, use 65532 to match the
image.

The chart runs the controller with `readOnlyRootFilesystem: true`. The image adds no writable paths, so the default
chart values need no volume mounts.

### Select a FIPS or dev variant

Image variants are identified by their tag. The runtime variants run the controller in production. The other variants
are listed below for each distro:

| Variant  | Debian 13 tag              | Alpine 3.24 tag              |
| :------- | :------------------------- | :--------------------------- |
| Runtime  | `1.26.0-debian13`          | `1.26.0-alpine3.24`          |
| FIPS     | `1.26.0-debian13-fips`     | `1.26.0-alpine3.24-fips`     |
| Dev      | `1.26.0-debian13-dev`      | `1.26.0-alpine3.24-dev`      |
| FIPS dev | `1.26.0-debian13-fips-dev` | `1.26.0-alpine3.24-fips-dev` |

The `-fips` variants use the Go native FIPS 140-3 module and the OpenSSL FIPS provider, and the image test suite
verifies them. The image is marked FIPS-compliant and STIG-certified. To run the FIPS variant, set `image.tag` to the
`-fips` tag. Keep `--reuse-values` on the upgrade: without it, Helm resets the release's own settings, such as the
credentials secret and the service account's IAM role annotation, to the chart defaults.

```bash
$ helm upgrade ack-eks oci://public.ecr.aws/aws-controllers-k8s/eks-chart \
  --version 1.26.0 \
  --namespace ack-system \
  --reuse-values \
  --set image.repository=dhi.io/aws-controllers-k8s-eks-controller \
  --set image.tag=1.26.0-debian13-fips \
  --set aws.region=us-west-2
```

The `-dev` variants run as root and include a shell and a package manager. They also keep the unstripped controller
binary. Use them for debugging, not for production.

## Common ACK EKS controller use cases

### Map a workload's service account to an IAM role

A `PodIdentityAssociation` binds a Kubernetes service account in a namespace of an EKS cluster to an IAM role. The
cluster must already exist in EKS, and the role's trust policy must allow the Pod Identity service principal.

```yaml
apiVersion: eks.services.k8s.aws/v1alpha1
kind: PodIdentityAssociation
metadata:
  name: app-s3-reader
  namespace: default
spec:
  clusterName: my-cluster
  namespace: default
  serviceAccount: app
  roleARN: arn:aws:iam::123456789012:role/app-s3-reader
  tags:
    team: platform
```

Apply the resource and check its status:

```bash
$ kubectl apply -f pod-identity-association.yaml
$ kubectl get podidentityassociations.eks.services.k8s.aws
```

## Non-hardened images vs. Docker Hardened Images

This image differs from the upstream image in two ways that affect deployment:

- User: the image runs as uid 65532 instead of uid 1000. See the user note above. The default chart values work without
  change.
- Shell and package manager: the runtime variants include neither. Use the `-dev` variants when you need a shell or a
  package manager.

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
