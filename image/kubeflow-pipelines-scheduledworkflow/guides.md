## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kubeflow-pipelines-scheduledworkflow:<tag>`
- Mirrored image: `<your-namespace>/dhi-kubeflow-pipelines-scheduledworkflow:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Kubeflow Pipelines Scheduled Workflow Controller image

The controller runs inside a Kubernetes cluster. It needs the `scheduledworkflows.kubeflow.org` CRD, RBAC rules for
ScheduledWorkflows and Argo Workflows, and a reachable Kubeflow Pipelines API server. Outside a cluster, the default
command exits with `Error building kubeconfig`. To check the image locally, print the available flags:

```bash
docker run --rm dhi.io/kubeflow-pipelines-scheduledworkflow:<tag> /bin/controller --help
```

Replace `<tag>` with a published tag, such as `2.18.1-debian13` or `2.18.1-alpine3.24`.

The image has no entrypoint, the same as the upstream image. Its default command is the upstream shell command, which
maps the environment variables below to controller flags. If you override the command, the environment variables no
longer configure the controller, so pass the settings as `/bin/controller` flags instead. Because there is no
entrypoint, the override must start with `/bin/controller`: a `docker run` command or a Kubernetes `args` list that
contains only flags has no program to run, and the container fails to start. In Kubernetes, set `command` to
`/bin/controller` and put the flags in `args`:

```yaml
containers:
  - name: ml-pipeline-scheduledworkflow
    command: ["/bin/controller"]
    args: ["--logtostderr=true", "--namespace=kubeflow", "--metricsPort=9090"]
```

### Environment variables

| Variable                  | Description                                                                                                                 | Default                              | Required |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ | -------- |
| `NAMESPACE`               | Namespace the controller watches. Leave it empty to watch all namespaces.                                                   | empty                                | No       |
| `MULTIUSER`               | On 2.18 and later, set to `true` to submit scheduled runs through the API server. 2.17 has no `-multiUser` flag.            | `false`                              | No       |
| `USER_IDENTITY_HEADER`    | gRPC metadata key that carries the controller's user identity to the API server in multi-user mode.                         | empty                                | No       |
| `USER_IDENTITY_VALUE`     | Value of the user identity key, for example `system:serviceaccount:kubeflow:ml-pipeline-scheduledworkflow`.                 | empty                                | No       |
| `LOG_LEVEL`               | Log level. The image sets it to `info`.                                                                                     | `info`                               | No       |
| `CLIENT_QPS`              | Maximum queries per second to the Kubernetes API server.                                                                    | `5`                                  | No       |
| `CLIENT_BURST`            | Maximum burst of requests to the Kubernetes API server.                                                                     | `10`                                 | No       |
| `RESYNC_INTERVAL_SECONDS` | Full resync interval, in seconds, for recurring run reconciliation.                                                         | `30`                                 | No       |
| `METRICS_PORT`            | Port of the Prometheus metrics endpoint.                                                                                    | `9090`                               | No       |
| `CRON_SCHEDULE_TIMEZONE`  | Time zone for cron schedules: `UTC`, `Local`, or an IANA name such as `America/New_York`. The controller reads it directly. | the container's local time zone, UTC | No       |

The upstream Deployment sets `NAMESPACE` to the pod's namespace, `CLIENT_QPS` to `10`, `CLIENT_BURST` to `20`, and
`CRON_SCHEDULE_TIMEZONE` from the `cronScheduleTimezone` key of the `pipeline-install-config` ConfigMap.

### Run in Kubernetes

Upstream runs the controller as the `ml-pipeline-scheduledworkflow` Deployment in the `kubeflow` namespace. To install
Kubeflow Pipelines with this image, first install the cluster-scoped resources, as in the
[upstream installation guide](https://www.kubeflow.org/docs/components/pipelines/operator-guides/installation/):

```bash
export PIPELINE_VERSION=2.18.1
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=$PIPELINE_VERSION"
kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io
```

Then create an overlay on the upstream `platform-agnostic` install. The overlay replaces the upstream controller image
with this image, and runs the controller as uid and gid 65532, the image's numeric user and group. Like the upstream
Deployment, it sets no `command` or `args`, so the image's default command starts the controller:

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - github.com/kubeflow/pipelines/manifests/kustomize/env/platform-agnostic?ref=2.18.1
images:
  - name: ghcr.io/kubeflow/kfp-scheduled-workflow-controller
    newName: dhi.io/kubeflow-pipelines-scheduledworkflow
    newTag: 2.18.1-debian13
patches:
  - target:
      kind: Deployment
      name: ml-pipeline-scheduledworkflow
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/securityContext/runAsUser
        value: 65532
      - op: replace
        path: /spec/template/spec/containers/0/securityContext/runAsGroup
        value: 65532
```

Apply it with:

```bash
kubectl apply -k .
```

Your cluster must be able to pull from `dhi.io`, for example through an image pull secret.

To switch an existing installation to this image, update the container image of the Deployment:

```bash
kubectl -n kubeflow set image deployment/ml-pipeline-scheduledworkflow \
  ml-pipeline-scheduledworkflow=dhi.io/kubeflow-pipelines-scheduledworkflow:<tag>
```

This keeps the upstream security context, `runAsUser: 1000` and `runAsGroup: 0`. The controller binary is world-readable
and executable, so the controller also starts as that user.

The controller connects to the API server over gRPC at `ml-pipeline:8887` by default, and exits if it cannot connect
within one minute. After it connects, it serves Prometheus metrics at `/metrics` on port 9090, the `containerPort` that
the upstream Deployment declares. Set `METRICS_PORT` to use a different port.

## Common Kubeflow Pipelines Scheduled Workflow Controller use cases

### Set the time zone for cron schedules

The controller reads `CRON_SCHEDULE_TIMEZONE`, which the upstream Deployment takes from the `cronScheduleTimezone` key
of the `pipeline-install-config` ConfigMap. The upstream default is `UTC`. The image includes time zone data, so IANA
names work. Add this entry to the `patches` list of the overlay:

```yaml
- target:
    kind: ConfigMap
    name: pipeline-install-config
  patch: |-
    - op: replace
      path: /data/cronScheduleTimezone
      value: America/New_York
```

The controller logs the time zone it uses at startup, for example `Location: America/New_York`. The Kubeflow Pipelines
API server reads the same ConfigMap key.

### Run in multi-user mode

For a multi-user install, use the upstream `platform-agnostic-multi-user` install as the overlay resource and keep the
same `images` and `patches` entries:

```yaml
resources:
  - github.com/kubeflow/pipelines/manifests/kustomize/env/platform-agnostic-multi-user?ref=2.18.1
```

On 2.18 and later, the upstream multi-user manifests set `MULTIUSER=true`, an empty `NAMESPACE` so that the controller
watches all namespaces, and `USER_IDENTITY_HEADER` and `USER_IDENTITY_VALUE` so that the controller's service account
identity is sent to the API server. The image's default command passes these to the controller, the same as the upstream
image. The 2.17 controller has no `-multiUser` flag, so the 2.17 default command does not pass `MULTIUSER`.

## Non-hardened images vs. Docker Hardened Images

- **User.** The runtime and FIPS runtime images run as `nonroot` (uid and gid 65532). The upstream image runs as
  `appuser` (uid 100, gid 65533), and the upstream Deployment overrides that with uid 1000 and gid 0. The overlay in
  [Run in Kubernetes](#run-in-kubernetes) sets uid and gid 65532 to match the image.
- **Default command.** The default command is the upstream shell command with an `exec` prefix, so the same environment
  variables configure the controller. The controller runs as the container's main process (PID 1) on both Debian and
  Alpine, and receives the `SIGTERM` that Kubernetes sends when it stops the pod.
- **Binary path.** The controller binary is at `/usr/bin/scheduledworkflow`, and `/bin/controller` is a symlink to it.
  Commands and manifests that run `/bin/controller` keep working.
- **Shell.** Runtime images include `/bin/sh`, because the default command needs it. The Alpine images use BusyBox
  `ash`, like the upstream image, and include the BusyBox applets, such as `ls`, `cat`, and `nc`. The Debian images use
  `dash` and do not include BusyBox, so `ls`, `cat`, and `nc` are not available. To inspect a running Debian container,
  use a `dev` variant, Docker Debug, or an ephemeral debug container.
- **Package manager.** The upstream image includes `apk`. Runtime images include no package manager.
- **Dev variants.** The `dev` variants run as root, and include `bash`, coreutils, findutils, and `apk` (Alpine) or
  `apt` (Debian). Their controller binary includes debug information.

## FIPS variants

The `-fips` and `-fips-dev` tags, such as `2.18.1-debian13-fips` and `2.18.1-alpine3.24-fips`, are FIPS builds. The
controller is built with the Go FIPS 140-3 module, and the images include an OpenSSL FIPS provider configured through
`OPENSSL_CONF`, `OPENSSL_MODULES`, and `SSL_CERT_FILE`. The FIPS runtime images run as `nonroot` (uid and gid 65532),
like the other runtime images. Use these tags when your environment requires FIPS-compliant builds.

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
