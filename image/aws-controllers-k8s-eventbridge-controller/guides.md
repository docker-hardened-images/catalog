## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-controllers-k8s-eventbridge-controller:1`
- Mirrored image: `<your-namespace>/dhi-aws-controllers-k8s-eventbridge-controller:1`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The AWS Controllers for Kubernetes (ACK) EventBridge controller is a Kubernetes operator. It runs inside a cluster,
reconciles Amazon EventBridge `EventBus`, `Rule`, `Archive`, and `Endpoint` custom resources
(`eventbridge.services.k8s.aws/v1alpha1`) with AWS, and calls AWS with the credentials you provide. Upstream
documentation for the custom resources and the IAM setup is at
https://github.com/aws-controllers-k8s/eventbridge-controller.

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

Version tags such as `1.10` and `1.10.0` point to the same Debian 13 runtime image as `1`. To pin both the version and
the base, use `1.10.0-debian13` or `1.10.0-alpine3.24`.

## Start an AWS Controllers for Kubernetes EventBridge controller image

The entrypoint is `/bin/controller`, the same as upstream, and the image sets no command. Arguments that you pass to
`docker run` are flags for the controller. Runtime tags run as UID 65532 (`nonroot`) and contain no shell.

The controller reconciles custom resources against AWS, so in practice you run it inside a Kubernetes cluster, installed
with Helm (see [Deploy with Helm](#deploy-with-helm)). Use `docker run` to check the image and its startup requirements.

### Basic usage

List the flags the controller accepts:

```bash
docker run --rm dhi.io/aws-controllers-k8s-eventbridge-controller:1 --help
```

At startup the controller needs an AWS region, AWS credentials, and Kubernetes access:

- The region comes from `AWS_REGION` or `--aws-region`. Without it, the controller exits with code 1 and logs
  `unable to start service controller as AWS region is missing`:

  ```bash
  docker run --rm dhi.io/aws-controllers-k8s-eventbridge-controller:1
  ```

- With a region set, the controller calls AWS STS to look up the account it runs in, so it also needs credentials from
  the AWS SDK default chain. Outside AWS and without credentials, it exits with code 1 and logs
  `no EC2 IMDS role found`:

  ```bash
  docker run --rm -e AWS_REGION=us-east-1 dhi.io/aws-controllers-k8s-eventbridge-controller:1
  ```

- Kubernetes access comes from the in-cluster service account when it runs in a pod, or from a kubeconfig when it runs
  outside the cluster.

### Common flags

| Flag                    | Purpose                                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------------------- |
| `--aws-region`          | AWS Region where the controller manages EventBridge resources. Same as `AWS_REGION`.                |
| `--watch-namespace`     | Comma-separated namespaces to watch. Unset means all namespaces.                                    |
| `--reconcile-resources` | Comma-separated resource kinds to reconcile, for example `EventBus,Rule`. Unset means all kinds.    |
| `--deletion-policy`     | `delete` (default) removes the AWS resource with the custom resource. `retain` keeps it.            |
| `--aws-endpoint-url`    | Overrides the EventBridge endpoint. An `http://` URL also needs `--allow-unsafe-aws-endpoint-urls`. |
| `--log-level`           | One of `debug`, `info` (default), `warn`, `error`, `dpanic`, `panic`, `fatal`.                      |
| `--metrics-addr`        | Address for the Prometheus metrics endpoint. Default `0.0.0.0:8080`.                                |
| `--healthz-addr`        | Address for the health probes, served at `/healthz` and `/readyz`. Default `0.0.0.0:8081`.          |

Credentials come from `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, a shared credentials file, or, on Amazon EKS, IAM
Roles for Service Accounts (IRSA). Set the credentials file path with `AWS_SHARED_CREDENTIALS_FILE`. The default is
`/.aws/credentials`, the same path as upstream, because the image sets `HOME=/`.

### Run with a read-only root filesystem

The Helm chart runs the controller with a read-only root filesystem. To check the image the same way, add `--read-only`:

```bash
docker run --rm --read-only -e AWS_REGION=us-east-1 dhi.io/aws-controllers-k8s-eventbridge-controller:1
```

Without credentials, this exits with the same credential error as above. It shows that the controller doesn't fail on
the read-only root filesystem during startup.

## Common AWS Controllers for Kubernetes EventBridge controller use cases

### Deploy with Helm

This quick start installs the upstream chart, `oci://public.ecr.aws/aws-controllers-k8s/eventbridge-chart` version
`1.10.0`, and points its image at this image. Prerequisites: a Kubernetes cluster, Helm 3.8 or later, and AWS
credentials with EventBridge permissions for the resources you manage.

1. Create the namespace and the AWS credentials secret. The chart reads the `credentials` key of the secret and mounts
   it at `/var/run/secrets/aws/credentials`. Write your access key to a shared credentials file first, in the standard
   `[default]` profile format.

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
   and the `-dev` tags run as root, so a pod with a `-dev` tag is rejected. The chart doesn't set `runAsUser`, so the
   pod runs as the image's numeric nonroot user, 65532. Add `--set image.pullSecrets[0]=dhi-pull-secret` when you
   created the pull secret in the previous step.

   ```bash
   helm install eventbridge-chart oci://public.ecr.aws/aws-controllers-k8s/eventbridge-chart \
     --version 1.10.0 \
     --namespace ack-system \
     --set image.repository=dhi.io/aws-controllers-k8s-eventbridge-controller \
     --set image.tag=1.10.0-debian13 \
     --set aws.region=us-east-1 \
     --set aws.credentials.secretName=aws-credentials
   ```

   Use `image.tag=1.10.0-alpine3.24` for Alpine 3.24, or a `-fips` tag from [FIPS variants](#fips-variants). Replace
   `us-east-1` with the Region where the controller manages resources. On Amazon EKS with IRSA, omit
   `aws.credentials.secretName` and set the `eks.amazonaws.com/role-arn` annotation under `serviceAccount.annotations`.
   The role must trust the `ack-eventbridge-controller` service account that the chart creates.

1. Check that the controller is running and healthy.

   ```bash
   kubectl -n ack-system rollout status deployment/eventbridge-chart
   kubectl -n ack-system port-forward deployment/eventbridge-chart 8081:8081
   ```

   In a second terminal, `curl -s http://localhost:8081/healthz` prints `ok`.

1. Optional: reconcile resources. Save this as `eventbridge.yaml`. It creates a custom event bus and a rule on that bus.
   The rule references the bus through `eventBusRef`, so the controller creates the rule after the bus is synced.

   ```yaml
   apiVersion: eventbridge.services.k8s.aws/v1alpha1
   kind: EventBus
   metadata:
     name: dhi-example-bus
     namespace: ack-system
   spec:
     name: dhi-example-bus
   ---
   apiVersion: eventbridge.services.k8s.aws/v1alpha1
   kind: Rule
   metadata:
     name: dhi-example-rule
     namespace: ack-system
   spec:
     name: dhi-example-rule
     eventBusRef:
       from:
         name: dhi-example-bus
     eventPattern: '{"source":["dhi.example"]}'
   ```

   Use the full resource names, such as `rule.eventbridge.services.k8s.aws`, so that `kubectl` doesn't resolve a bare
   `rule` to another API group.

   ```bash
   kubectl apply -f eventbridge.yaml
   kubectl -n ack-system wait --for=condition=ACK.ResourceSynced=True \
     eventbus.eventbridge.services.k8s.aws/dhi-example-bus rule.eventbridge.services.k8s.aws/dhi-example-rule \
     --timeout=2m
   kubectl -n ack-system delete rule.eventbridge.services.k8s.aws dhi-example-rule
   kubectl -n ack-system delete eventbus.eventbridge.services.k8s.aws dhi-example-bus
   ```

   With the default `delete` deletion policy, deleting the custom resources deletes the rule and the event bus in AWS.

### Configure the controller

The chart maps its values to controller flags:

| Chart value           | Controller flag         | Notes                                                                           |
| --------------------- | ----------------------- | ------------------------------------------------------------------------------- |
| `aws.region`          | `--aws-region`          | Required. Also sets `AWS_REGION`.                                               |
| `reconcile.resources` | `--reconcile-resources` | Defaults to `Archive`, `Endpoint`, `EventBus`, and `Rule`.                      |
| `deletionPolicy`      | `--deletion-policy`     | `delete` (default) or `retain`.                                                 |
| `watchNamespace`      | `--watch-namespace`     | Applies only when `installScope: namespace`. Defaults to the release namespace. |
| `log.level`           | `--log-level`           | `info` by default.                                                              |
| `aws.endpoint_url`    | `--aws-endpoint-url`    | Plain `http://` URLs also need `aws.allow_unsafe_aws_endpoint_urls: true`.      |

### Use the -dev variant for debugging only

The `-dev` variants run as root and include a shell, coreutils, findutils, and the package manager (`apt` on Debian,
`apk` on Alpine). Use them to inspect the controller binary or debug a problem, not to run the controller:

```bash
docker run --rm --entrypoint bash dhi.io/aws-controllers-k8s-eventbridge-controller:1-dev -c 'id; ls -l /bin/controller /usr/bin/controller'
```

Deploy a runtime tag, such as `1`, `1-fips`, or `1-alpine`, in production.

## Non-hardened images vs. Docker Hardened Images

The command path matches upstream: `/bin/controller` is still the entrypoint, and the chart's `./bin/controller` command
resolves to it. One difference affects how you deploy the image:

- **User.** The upstream image runs as UID 1000. Docker Hardened runtime variants run as UID 65532 (`nonroot`). Change
  any `runAsUser: 1000` in your manifests to `65532`, and make sure that any file, Secret, or volume that the controller
  reads is readable by UID 65532. The `-dev` tags run as root.

## FIPS variants

- The `-fips` and `-fips-dev` tags build the controller with the FIPS 140-3 Go Cryptographic Module
  (`GOFIPS140=v1.0.0`). The default runtime setting is `fips140=on`, so TLS connections to AWS use the FIPS module and
  negotiate only FIPS-approved cipher suites. An endpoint that offers only non-approved cipher suites, for example one
  set with `--aws-endpoint-url`, fails the TLS handshake.
- The FIPS images include the OpenSSL FIPS provider.
- The FIPS runtime tags run as UID 65532, the same as the standard runtime tags.

Debian 13 FIPS tags: `1.10.0-fips` (runtime) and `1.10.0-fips-dev` (dev), also published as `1.10.0-debian13-fips` and
`1.10.0-debian13-fips-dev`. Alpine 3.24 FIPS tags: `1.10.0-alpine3.24-fips` (runtime) and `1.10.0-alpine3.24-fips-dev`
(dev).

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
