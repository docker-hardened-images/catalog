## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-controllers-k8s-sns-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-controllers-k8s-sns-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Image tags

| Tag                 | Base        | Variant                |
| ------------------- | ----------- | ---------------------- |
| `1`                 | Debian 13   | Runtime                |
| `1-dev`             | Debian 13   | Build-time (dev)       |
| `1-fips`            | Debian 13   | Runtime, FIPS          |
| `1-fips-dev`        | Debian 13   | Build-time (dev), FIPS |
| `1-alpine`          | Alpine 3.24 | Runtime                |
| `1-alpine-dev`      | Alpine 3.24 | Build-time (dev)       |
| `1-alpine-fips`     | Alpine 3.24 | Runtime, FIPS          |
| `1-alpine-fips-dev` | Alpine 3.24 | Build-time (dev), FIPS |

Version tags such as `1.13` and `1.13.0` point to the same Debian 13 runtime image as `1`.

## Start an ACK SNS controller image

The controller reconciles SNS custom resources against AWS, so in practice you run it inside a Kubernetes cluster,
installed with Helm (see [Install with Helm](#install-with-helm)). Use `docker run` to check the image and its startup
requirements.

At startup the controller needs an AWS region and AWS credentials:

- The region comes from `AWS_REGION` or `--aws-region`. Without it, the controller exits with code 1.
- With a region set, the controller calls AWS STS at startup to look up the account it runs in, so it also needs
  credentials. Without credentials it exits with code 1.

### Basic usage

List the flags the controller accepts:

```bash
docker run --rm dhi.io/aws-controllers-k8s-sns-controller:1 --help
```

Start the controller without a region. It exits with code 1 and logs
`unable to start service controller as AWS region is missing`:

```bash
docker run --rm dhi.io/aws-controllers-k8s-sns-controller:1
```

Set a region but no credentials. Outside AWS, the controller exits with code 1 and logs `no EC2 IMDS role found`:

```bash
docker run --rm -e AWS_REGION=us-east-1 dhi.io/aws-controllers-k8s-sns-controller:1
```

Supply credentials with `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, a shared credentials file (see
[Environment variables](#environment-variables)), or, in a cluster, IAM Roles for Service Accounts (IRSA) through the
chart's `serviceAccount.annotations`.

By default, metrics listen on port 8080 and health probes on port 8081 (`--metrics-addr` and `--healthz-addr`).

### Run with a read-only root filesystem

The image runs as UID 65532 (`nonroot`) by default, so you don't need `--user`. The Helm chart runs the controller with
a read-only root filesystem. To check the image the same way, add `--read-only`:

```bash
docker run --rm --read-only -e AWS_REGION=us-east-1 dhi.io/aws-controllers-k8s-sns-controller:1
```

Without credentials, this exits with the same credential error as above. It shows that the controller doesn't fail on
the read-only root filesystem during startup.

## Environment variables

| Variable                      | Description                                                                                                                                                        | Default                                        | Required                                        |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------- | ----------------------------------------------- |
| `AWS_REGION`                  | AWS region for API calls. Same as `--aws-region`.                                                                                                                  | None                                           | Yes, unless `--aws-region` is set               |
| `AWS_ACCESS_KEY_ID`           | Access key ID for static credentials. Use with `AWS_SECRET_ACCESS_KEY`.                                                                                            | None                                           | No. Use IRSA or a credentials file in a cluster |
| `AWS_SECRET_ACCESS_KEY`       | Secret access key for static credentials.                                                                                                                          | None                                           | Only with `AWS_ACCESS_KEY_ID`                   |
| `AWS_SHARED_CREDENTIALS_FILE` | Path to an AWS shared credentials file.                                                                                                                            | `$HOME/.aws/credentials` (`/.aws/credentials`) | No                                              |
| `AWS_ENDPOINT_URL`            | Overrides the AWS endpoint the SDK calls. The controller's `--aws-endpoint-url` flag rejects `http://` URLs unless `--allow-unsafe-aws-endpoint-urls` is also set. | None                                           | No                                              |
| `AWS_CA_BUNDLE`               | PEM CA bundle used to verify TLS connections to AWS endpoints.                                                                                                     | None                                           | No                                              |

Set the log level with the `--log-level` flag. The Helm chart sets it from `log.level`. The binary doesn't read an
`ACK_LOG_LEVEL` environment variable; the chart sets that variable and passes it to `--log-level`.

## Common ACK SNS controller use cases

### Install with Helm

The upstream Helm chart runs the image from its `image.repository` and `image.tag` values. Set both to the DHI image.
Save this as `values.yaml`, replacing the placeholders with your AWS account ID and IAM role name:

```yaml
aws:
  region: us-east-1
image:
  repository: dhi.io/aws-controllers-k8s-sns-controller
  tag: "1"
  pullSecrets:
    - dhi-pull-secret
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::<AWS_ACCOUNT_ID>:role/<IAM_ROLE_NAME>"
```

If your cluster pulls from `dhi.io` with credentials, create a `docker-registry` secret named `dhi-pull-secret` in the
`ack-system` namespace, as listed under `image.pullSecrets`.

Install the chart:

```bash
helm install ack-sns-controller oci://public.ecr.aws/aws-controllers-k8s/sns-chart \
  --version 1.13.0 \
  --namespace ack-system \
  --create-namespace \
  -f values.yaml
```

The IAM role must trust your cluster's OIDC provider for the `ack-sns-controller` service account in the `ack-system`
namespace. The chart creates that service account when `serviceAccount.create` is `true`, which is the default.

### Configure the controller

The chart maps its values to controller flags. Add these values to your `values.yaml`:

```yaml
installScope: namespace
watchNamespace: team-a
log:
  level: debug
deletionPolicy: retain
reconcile:
  resources:
    - Topic
    - Subscription
```

With `installScope: namespace`, the chart creates a Role and RoleBinding in the watched namespace. The
`--create-namespace` flag in the install command creates only the `ack-system` release namespace, so create the watched
namespace first, then apply the values to the existing release:

```bash
kubectl create namespace team-a
helm upgrade ack-sns-controller oci://public.ecr.aws/aws-controllers-k8s/sns-chart \
  --version 1.13.0 \
  --namespace ack-system \
  -f values.yaml
```

| Chart value           | Controller flag         | Notes                                                                      |
| --------------------- | ----------------------- | -------------------------------------------------------------------------- |
| `aws.region`          | `--aws-region`          | Required. Also sets `AWS_REGION`.                                          |
| `log.level`           | `--log-level`           | `debug`, `info` (default), `warn`, `error`, `dpanic`, `panic`, `fatal`.    |
| `deletionPolicy`      | `--deletion-policy`     | `delete` (default) or `retain`.                                            |
| `watchNamespace`      | `--watch-namespace`     | Applies only when `installScope: namespace`.                               |
| `reconcile.resources` | `--reconcile-resources` | Resource kinds to reconcile, for example `Topic` and `Subscription`.       |
| `aws.endpoint_url`    | `--aws-endpoint-url`    | Plain `http://` URLs also need `aws.allow_unsafe_aws_endpoint_urls: true`. |

### Use the -dev variant for debugging only

The `-dev` variants run as root and include a shell and common utilities. Use them to inspect the controller binary or
debug a problem, not to run the controller:

```bash
docker run --rm --entrypoint bash dhi.io/aws-controllers-k8s-sns-controller:1-dev -c 'id; ls -l /bin/controller /usr/bin/controller'
```

Deploy a runtime tag, such as `1`, `1-fips`, or `1-alpine`, in production.

## Non-hardened images vs. Docker Hardened Images

The command path matches upstream: `/bin/controller` is still the entrypoint, and the chart's `./bin/controller` command
resolves to it. One difference affects how you deploy the image:

- **User.** The upstream image runs as UID 1000. Docker Hardened runtime variants run as UID 65532 (`nonroot`). Any
  file, Secret, or volume that the controller reads must be readable by UID 65532.

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
