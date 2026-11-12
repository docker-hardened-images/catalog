## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-controllers-k8s-sqs-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-controllers-k8s-sqs-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

AWS Controllers for Kubernetes (ACK) SQS controller runs in a cluster and reconciles `Queue` custom resources into
Amazon SQS queues. This image replaces `public.ecr.aws/aws-controllers-k8s/sqs-controller` on the 1.x line. It is a
drop-in for the upstream release image: the same entrypoint, working directory and flags. The upstream project documents
the custom resources, IAM permissions and Helm chart at https://github.com/aws-controllers-k8s/sqs-controller.

The runtime tags are `dhi.io/aws-controllers-k8s-sqs-controller:1-alpine3.24` (Alpine 3.24) and
`dhi.io/aws-controllers-k8s-sqs-controller:1-debian13` (Debian 13). The version tags, such as `1.9.0-debian13`, pin the
release.

## Start an ACK SQS controller image

The entrypoint is `/bin/controller`, and the image sets no command. Runtime tags run as user 65532 and contain no shell.

### Basic usage

```bash
docker run --rm dhi.io/aws-controllers-k8s-sqs-controller:1-debian13 --help
```

The controller needs an AWS Region and AWS credentials before it starts. Without a Region it exits with
`AWS region is missing`. Pass `--aws-region`, or set `AWS_REGION`, and provide credentials through the usual AWS SDK
variables such as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, or through IAM roles for service accounts in a
cluster.

Outside a cluster, point the `KUBECONFIG` environment variable at a kubeconfig file. The controller reads the in-cluster
configuration when no kubeconfig is set.

Credentials from a file are read from `/.aws/credentials`, the same path upstream uses, or from the path in
`AWS_SHARED_CREDENTIALS_FILE`. Mount the file read-only and make it readable by UID 65532. For example, mode `0644` is
readable by UID 65532.

### Install with the upstream Helm chart

Install the upstream chart and point its image at this image. The chart runs the controller as a non-root user with a
read-only root filesystem, so use a runtime tag. Dev tags run as root and the pod is rejected.

```bash
helm install ack-sqs-controller oci://public.ecr.aws/aws-controllers-k8s/sqs-chart \
  --version 1.9.0 \
  --namespace ack-system --create-namespace \
  --set image.repository=dhi.io/aws-controllers-k8s-sqs-controller \
  --set image.tag=1.9.0-debian13 \
  --set aws.region=us-east-1
```

The chart does not set `runAsUser`, so the numeric nonroot user of the image is what the pod runs as. Create the
`dhi-pull-secret` image pull secret for `dhi.io` in the target namespace first, and add it to the chart with
`--set image.pullSecrets[0]=dhi-pull-secret` when the registry requires it. The chart reads the secret names from
`image.pullSecrets`, as plain strings.

### Manage a queue

After the controller is ready, a `Queue` custom resource creates a queue in AWS. The controller reports
`ACK.ResourceSynced` on the resource once the queue exists.

```yaml
apiVersion: sqs.services.k8s.aws/v1alpha1
kind: Queue
metadata:
  name: orders
  namespace: default
spec:
  queueName: orders
  delaySeconds: "5"
```

Deleting the resource deletes the queue.

### Health and metrics

The controller serves Prometheus metrics on port 8080 (`--metrics-addr`) and health probes on port 8081
(`--healthz-addr`). The image declares both ports. The chart probes `/healthz` and `/readyz` on 8081.

To read the metrics from your workstation, forward the port to the controller Deployment. With the release name
`ack-sqs-controller`, the chart names the Deployment `ack-sqs-controller-sqs-chart`:

```bash
kubectl -n ack-system port-forward deploy/ack-sqs-controller-sqs-chart 8080
```

Then read the metrics from another terminal:

```bash
curl -s http://localhost:8080/metrics | grep ack_outbound_api_requests_total
```

## Non-hardened images vs. Docker Hardened Images

- The images are built for `linux/amd64` and `linux/arm64`. The upstream image runs as UID 1000. This image runs as
  nonroot UID 65532, which is the Docker Hardened Images convention. The chart's `runAsNonRoot` check accepts any
  numeric non-zero UID, and the controller writes no files, so the UID change needs no volume or ownership changes for
  its own output. Credential and kubeconfig files you mount from an upstream setup must be readable by UID 65532, not
  only by UID 1000. The image keeps `HOME` at `/` as upstream does, so the default credentials file is
  `/.aws/credentials` and the default AWS config file is `/.aws/config`. Set `AWS_SHARED_CREDENTIALS_FILE` to read the
  credentials from another path.
- The upstream binary is named `controller`, and the packaged binary is named `ack-sqs-controller`. The image keeps the
  upstream entrypoint `/bin/controller`, so manifests that run the entrypoint or `./bin/controller` keep working. On the
  Alpine tags, `/usr/bin/controller` is a symlink to `/usr/bin/ack-sqs-controller`, the same as on the Debian tags, so
  both upstream invocation paths work on both distros. Use `/bin/controller`, `/usr/bin/controller`, or
  `/usr/bin/ack-sqs-controller` there.
- The Debian tags install Debian's `tzdata` without `tzdata-legacy`, so legacy zone names such as `US/Eastern` are
  missing and `TZ` set to one falls back to UTC. Use a canonical name such as `America/New_York`, or an Alpine tag.

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
