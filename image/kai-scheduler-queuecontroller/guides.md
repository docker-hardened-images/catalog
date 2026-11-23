## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kai-scheduler-queuecontroller:<tag>`
- Mirrored image: `<your-namespace>/dhi-kai-scheduler-queuecontroller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Image tags

The tags below are for the 0.19 line, which matches KAI Scheduler v0.19.0.

| Tag                    | Base        | Variant                |
| ---------------------- | ----------- | ---------------------- |
| `0.19`                 | Debian 13   | Runtime                |
| `0.19-dev`             | Debian 13   | Build-time (dev)       |
| `0.19-fips`            | Debian 13   | Runtime, FIPS          |
| `0.19-fips-dev`        | Debian 13   | Build-time (dev), FIPS |
| `0.19-alpine`          | Alpine 3.24 | Runtime                |
| `0.19-alpine-dev`      | Alpine 3.24 | Build-time (dev)       |
| `0.19-alpine-fips`     | Alpine 3.24 | Runtime, FIPS          |
| `0.19-alpine-fips-dev` | Alpine 3.24 | Build-time (dev), FIPS |

Patch version tags such as `0.19.0` and `0.19.0-fips` point to the same images. The 0.18, 0.16, 0.14 and 0.12 lines
publish the same variants, for example `0.18`, `0.16.18-fips` or `0.12-alpine`. Only the 0.19 line also publishes the
`0` tags. Use the line that matches the KAI Scheduler release you run.

## Start a KAI Scheduler queue controller image

The queue controller is one component of KAI Scheduler. It reconciles `queues.scheduling.run.ai` Queue resources,
keeping their status (including the child queues of a hierarchical queue) and queue metrics up to date, and it serves a
validating admission webhook for Queues. In a KAI Scheduler installation, the KAI operator creates and configures its
Deployment, so you run this image by pointing the operator at it (see
[Use the image in a KAI Scheduler installation](#use-the-image-in-a-kai-scheduler-installation)).

### Basic usage

List the flags the controller accepts:

```bash
docker run --rm dhi.io/kai-scheduler-queuecontroller:0.19 --help
```

The controller has no version flag. Without access to a cluster, it exits with code 1 and logs
`unable to load in-cluster config`. On the 0.14 and 0.12 lines, the controller connects to the cluster before it parses
flags, so `--help` also exits with that error outside a cluster.

By default, the controller serves metrics on port 8080 (`--metrics-listen-address`) and the Queue validating webhook on
port 9443 (`--enable-webhook`). The webhook reads its certificate and key from `tls.crt` and `tls.key` in
`/tmp/k8s-webhook-server/serving-certs`, where the operator mounts them.

## Common KAI Scheduler queue controller use cases

### Use the image in a KAI Scheduler installation

The KAI Scheduler Helm chart builds every component image from one shared `global.registry` prefix, so chart values
can't select this image for the queue controller alone. Install the chart, then set the queue controller image in the
`kai-config` Config resource that the operator reads. The operator builds the image reference as
`<repository>/<name>:<tag>` from `spec.queueController.service.image`.

Create the namespace and a pull secret for `dhi.io`. Then install the chart version that matches the image line, attach
the secret to the KAI components with `global.imagePullSecrets`, and set `global.securityContext` to the image's user
and group, UID and GID 65532:

```bash
kubectl create namespace kai-scheduler
kubectl -n kai-scheduler create secret docker-registry dhi-pull-secret \
  --docker-server=dhi.io --docker-username=<username> --docker-password=<token>
helm upgrade -i kai-scheduler oci://ghcr.io/kai-scheduler/kai-scheduler/kai-scheduler \
  -n kai-scheduler --version v0.19.0 \
  --set 'global.imagePullSecrets[0].name=dhi-pull-secret' \
  --set global.securityContext.runAsUser=65532 \
  --set global.securityContext.runAsGroup=65532
```

Without `global.securityContext.runAsUser`, the operator runs every KAI container as UID 10000. The chart copies
`global.securityContext` into `kai-config`, and the operator applies it to all the KAI components it deploys, keeping
its `runAsNonRoot`, no-privilege-escalation and drop-all-capabilities defaults. The upstream KAI images also run as
65532:65532.

Point the queue controller at the Docker Hardened Image:

```bash
kubectl patch config kai-config --type merge \
  -p '{"spec":{"queueController":{"service":{"image":{"repository":"dhi.io","name":"kai-scheduler-queuecontroller","tag":"0.19"}}}}}'
```

The operator rolls out the `queue-controller` Deployment with the new image:

```bash
kubectl -n kai-scheduler rollout status deployment/queue-controller
kubectl -n kai-scheduler get deployment queue-controller \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}{.spec.template.spec.containers[0].securityContext}{"\n"}'
```

The second line of output shows `"runAsUser":65532` and `"runAsGroup":65532`.

Running `helm upgrade` re-applies `kai-config` and resets the queue controller image to the chart default. Pass the same
`global.securityContext` values to every upgrade, and run the `kubectl patch` command again afterwards. To manage
`kai-config` yourself instead, see the
[upstream GitOps guide](https://github.com/kai-scheduler/KAI-Scheduler/blob/v0.19.0/docs/gitops/README.md), which
describes `kaiConfigDeployer.enabled`.

### Run a FIPS variant

Set a `-fips` tag in `kai-config`:

```bash
kubectl patch config kai-config --type merge \
  -p '{"spec":{"queueController":{"service":{"image":{"repository":"dhi.io","name":"kai-scheduler-queuecontroller","tag":"0.19-fips"}}}}}'
```

The chart's `global.fipsMode` value only changes the tags that the chart renders. It doesn't change a tag that you set
with `kubectl patch`.

### Check the queue controller

KAI Scheduler creates `default-parent-queue` and `default-queue` at install time. The queue controller lists each
queue's children in its status, which `kubectl get queues` shows in the `CHILDREN` column:

```bash
kubectl get queues
```

To read the queue metrics, such as `kai_queue_info`, forward the metrics port:

```bash
kubectl -n kai-scheduler port-forward service/queue-controller 8080:8080
```

Then, in another terminal, query the endpoint:

```bash
curl -s http://localhost:8080/metrics | grep kai_queue_info
```

For queue configuration, quotas and hierarchies, see the
[upstream queue documentation](https://github.com/kai-scheduler/KAI-Scheduler/blob/v0.19.0/docs/queues/README.md).

### Use the -dev variant for debugging only

The `-dev` variants run as root and include a shell, common utilities and the package manager. Use them to inspect the
image or debug a problem, not to run the controller:

```bash
docker run --rm --entrypoint bash dhi.io/kai-scheduler-queuecontroller:0.19-dev -c 'id; ls -l /workspace'
```

Use a runtime tag, such as `0.19`, `0.19-fips` or `0.19-alpine`, in the cluster.

## Non-hardened images vs. Docker Hardened Images

The entrypoint (`/workspace/app`), working directory (`/workspace`) and default user (UID and GID 65532) match the
upstream image. The differences are:

- **Exposed ports.** The Docker Hardened Image declares the metrics port 8080 and the webhook port 9443 as exposed
  ports; the upstream image declares none. The controller listens on the same ports in both images, so this metadata
  doesn't change how you deploy it.
- **Image name and tags.** The upstream image is `ghcr.io/kai-scheduler/kai-scheduler/queuecontroller:v0.19.0`. The
  Docker Hardened Image is `dhi.io/kai-scheduler-queuecontroller`, and its tags have no `v` prefix. Because the name
  differs, set the image in `kai-config` as shown in
  [Use the image in a KAI Scheduler installation](#use-the-image-in-a-kai-scheduler-installation) instead of through
  chart values.

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
