## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-controllers-k8s-iam-controller:1`
- Mirrored image: `<your-namespace>/dhi-aws-controllers-k8s-iam-controller:1`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The AWS Controllers for Kubernetes (ACK) IAM controller is a Kubernetes operator. It runs inside a cluster, reconciles
AWS IAM resources that you declare as Kubernetes custom resources, and calls AWS with the credentials you provide. The
image's entrypoint is the controller binary, `/bin/controller`. Upstream documentation for the custom resources and the
IAM setup is at https://github.com/aws-controllers-k8s/iam-controller.

The Debian 13 runtime tag is `dhi.io/aws-controllers-k8s-iam-controller:1.12.0-debian13`. The Alpine 3.24 runtime tag is
`dhi.io/aws-controllers-k8s-iam-controller:1.12.0-alpine3.24`. The shorter tags `1` and `1.12` point to the Debian 13
runtime image.

## Start an AWS Controllers for Kubernetes IAM controller image

The entrypoint is `/bin/controller`, and the image sets no command. Arguments that you pass to `docker run` are flags
for the controller. Runtime tags run as user 65532 and contain no shell.

### Basic usage

```bash
docker run --rm dhi.io/aws-controllers-k8s-iam-controller:1 --help
```

The output lists every flag the controller accepts. There is no `--version` flag.

### Configure credentials and the cluster

The controller needs two things at startup:

- Kubernetes access: in-cluster service account configuration when it runs in a pod, or a kubeconfig when it runs
  outside the cluster.
- AWS credentials from the AWS SDK default credential chain: environment variables, the shared credentials file, or web
  identity (IAM Roles for Service Accounts, IRSA). The controller calls AWS STS when it starts, so startup fails without
  credentials.

### Common flags

| Flag                    | Purpose                                                                                                                                   |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `--aws-region`          | AWS Region where the controller creates resources.                                                                                        |
| `--watch-namespace`     | Comma-separated namespaces to watch. Unset means all namespaces.                                                                          |
| `--reconcile-resources` | Comma-separated resource kinds to reconcile. Unset means all kinds.                                                                       |
| `--aws-endpoint-url`    | Overrides the AWS endpoint, for example a LocalStack-style test endpoint. An `http://` URL also needs `--allow-unsafe-aws-endpoint-urls`. |
| `--log-level`           | One of `debug`, `info` (default), `warn`, `error`, `dpanic`, `panic`, `fatal`.                                                            |
| `--metrics-addr`        | Address for the metrics endpoint. Default `0.0.0.0:8080`.                                                                                 |
| `--healthz-addr`        | Address for the health probes. Default `0.0.0.0:8081`.                                                                                    |

The image exposes `8080/tcp` for metrics and `8081/tcp` for health probes, served at `/healthz` and `/readyz`.

### Deploy with Helm

This quick start installs the upstream chart, `oci://public.ecr.aws/aws-controllers-k8s/iam-chart` version `1.12.0`, and
points its image at this image. Prerequisites: a Kubernetes cluster, Helm 3.8 or later, and an AWS account with IAM
permissions for the resources you manage. The upstream project documents the custom resources and IAM setup at
https://github.com/aws-controllers-k8s/iam-controller.

1. Create the namespace and the AWS credentials secret. The chart reads the `credentials` key of the `aws-credentials`
   secret. Write your access key to a shared credentials file first, in the standard `[default]` profile format.

   ```bash
   kubectl create namespace ack-system
   kubectl -n ack-system create secret generic aws-credentials --from-file=credentials=./credentials
   ```

1. If the cluster pulls from `dhi.io` with credentials, create a pull secret in the same namespace. Skip this step when
   the pull is anonymous.

   ```bash
   kubectl -n ack-system create secret docker-registry dhi-pull-secret \
     --docker-server=dhi.io --docker-username=<username> --docker-password=<token>
   ```

1. Install the chart with this image. Use a runtime tag. The chart sets `runAsNonRoot` and a read-only root filesystem,
   and the `-dev` tags run as root, so the pod is rejected. The chart does not set `runAsUser`, so the pod runs as the
   numeric nonroot user 65532 of the image. Add `--set image.pullSecrets[0]=dhi-pull-secret` when you created the pull
   secret in the previous step.

   ```bash
   helm install iam-chart oci://public.ecr.aws/aws-controllers-k8s/iam-chart \
     --version 1.12.0 \
     --namespace ack-system \
     --set image.repository=dhi.io/aws-controllers-k8s-iam-controller \
     --set image.tag=1.12.0-debian13 \
     --set aws.region=us-east-1 \
     --set aws.credentials.secretName=aws-credentials
   ```

   Use `image.tag=1.12.0-alpine3.24` for Alpine 3.24, or a `-fips` tag from the FIPS section. Replace `us-east-1` with
   the Region where the controller creates resources.

1. Check that the controller is running and healthy.

   ```bash
   kubectl -n ack-system rollout status deployment/iam-chart
   kubectl -n ack-system port-forward deployment/iam-chart 8081:8081
   ```

   In a second terminal, `curl -s http://localhost:8081/healthz` prints `ok`. The rollout completes when the pod is
   ready.

1. Optional: reconcile a resource. This creates an IAM role and waits for ACK to report it synced.

   ```yaml
   apiVersion: iam.services.k8s.aws/v1alpha1
   kind: Role
   metadata:
     name: dhi-role-example
     namespace: ack-system
   spec:
     name: dhi-role-example
     assumeRolePolicyDocument: '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
   ```

   Use the full resource name `role.iam.services.k8s.aws`. A bare `role` resolves to the Kubernetes RBAC `Role` kind.

   ```bash
   kubectl -n ack-system apply -f role.yaml
   kubectl -n ack-system wait --for=condition=ACK.ResourceSynced=True role.iam.services.k8s.aws/dhi-role-example --timeout=2m
   kubectl -n ack-system delete role.iam.services.k8s.aws dhi-role-example
   ```

   Deleting the custom resource deletes the IAM role in AWS.

## Non-hardened images vs. Docker Hardened Images

- **User:** The upstream image runs as user `1000`. The runtime and FIPS runtime tags run as user `65532`. Change any
  `runAsUser: 1000` in your manifests to `65532`. The `-dev` tags run as root.
- **Entrypoint:** The entrypoint is `/bin/controller`, the same as upstream, so you do not need a workaround. On the
  Alpine tags, `/bin/controller` is a symlink to `/usr/bin/controller`. The Debian tags use `/usr/bin/controller`
  through the merged `/bin` directory. Neither layout changes how you run the controller.

## FIPS variants

- The `-fips` and `-fips-dev` tags build the controller with the FIPS 140 Go cryptographic module (`GOFIPS140=v1.0.0`).
  The default runtime setting is `fips140=on`, so TLS connections to AWS use the FIPS module.
- The FIPS images include the OpenSSL FIPS provider.
- The FIPS runtime tags run as user `65532`, the same as the standard runtime tags.

Debian 13 FIPS tags: `1.12.0-debian13-fips` (runtime) and `1.12.0-debian13-fips-dev` (dev). Alpine 3.24 FIPS tags:
`1.12.0-alpine3.24-fips` (runtime) and `1.12.0-alpine3.24-fips-dev` (dev).

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
