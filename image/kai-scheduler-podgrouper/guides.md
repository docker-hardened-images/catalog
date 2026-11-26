## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kai-scheduler-podgrouper:<tag>`
- Mirrored image: `<your-namespace>/dhi-kai-scheduler-podgrouper:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a kai-scheduler-podgrouper image

Podgrouper is the KAI Scheduler controller that groups workload pods into PodGroups. It isn't run on its own: the KAI
operator deploys it from the configuration that the
[KAI Scheduler Helm chart](https://github.com/kai-scheduler/KAI-scheduler) installs. Use a runtime tag in the cluster.

### Run podgrouper directly

Podgrouper needs a cluster to talk to, so outside Kubernetes it only prints its usage:

```bash
$ docker run --rm dhi.io/kai-scheduler-podgrouper:<tag> --help
```

### Install KAI Scheduler with this image

The chart builds every KAI image, podgrouper included, as `<global.registry>/<image name>:<tag>`. There is no
per-component registry setting, so `podgrouper.image.name` and `podgrouper.image.tag` alone can't point podgrouper at
`dhi.io`. Put this image in a registry path of your own, next to copies of the other KAI images, and set
`global.registry` to that path.

Copy the images for the chart version you install. Chart `v0.12.29` needs other copies, shown in *Chart version
v0.12.29* below. The Debian 13 runtime and FIPS variants publish `v`-prefixed tags, such as `v0.19.0` and
`v0.19.0-fips`, which match the tags the chart resolves by default:

```bash
$ docker buildx imagetools create \
  --tag <your-namespace>/dhi-kai-scheduler-podgrouper:v0.19.0 \
  dhi.io/kai-scheduler-podgrouper:v0.19.0
$ for image in operator admission binder scheduler podgroupcontroller queuecontroller \
    resourcereservation nodescaleadjuster scalingpod numa-placement-exporter helm-hooks; do
    docker buildx imagetools create \
      --tag <your-namespace>/$image:v0.19.0 \
      ghcr.io/kai-scheduler/kai-scheduler/$image:v0.19.0
  done
```

For chart versions `v0.16.18` and `v0.14.14`, replace `helm-hooks` with `crd-upgrader`. Chart version `v0.14.14` has no
`numa-placement-exporter` image.

Create a pull secret for your registry and install the chart. `global.imagePullSecrets` is passed to every KAI
component, `podgrouper.image.name` selects this image in your registry path, and `global.securityContext` runs the
containers as the image's nonroot user:

```bash
$ kubectl create namespace kai-scheduler
$ kubectl -n kai-scheduler create secret docker-registry mirror-pull-secret \
  --docker-server=<your-registry> --docker-username=<username> --docker-password=<token>
$ helm install kai-scheduler oci://ghcr.io/kai-scheduler/kai-scheduler/kai-scheduler \
  --version v0.19.0 --namespace kai-scheduler \
  --set global.registry=<your-namespace> \
  --set 'global.imagePullSecrets[0].name=mirror-pull-secret' \
  --set podgrouper.image.name=dhi-kai-scheduler-podgrouper \
  --set global.securityContext.runAsUser=65532 \
  --set global.securityContext.runAsGroup=65532
```

Without `global.securityContext`, the operator runs every KAI container as user `10000`. User and group `65532` are this
image's nonroot user and the user of every upstream KAI image, and the setting applies to all of them and to the chart's
hook jobs. The operator keeps its other defaults: non-root, no privilege escalation, and all capabilities dropped.
Podgrouper writes no files, so it needs no writable volume or `fsGroup`.

Alpine tags have no `v` prefix. To run the Alpine variant, copy a tag such as `0.19.0-alpine3.24` to your registry path
and add `--set podgrouper.image.tag=0.19.0-alpine3.24`. On chart `v0.12.29`, see *Chart version v0.12.29* below instead.

The operator reads the image from the `kai-config` Config resource that the chart applies. Editing that resource
directly changes the image only until the next `helm upgrade`, which applies the chart's values again.

### Select the FIPS images

The chart's FIPS setting appends `-fips` to every KAI image tag, so your registry path needs the `-fips` tag of every
image you copied. If you set `podgrouper.image.tag`, keep it without the suffix.

| Chart version        | FIPS setting               |
| :------------------- | :------------------------- |
| `v0.19.0`, `v0.18.8` | `--set global.fipsMode=on` |
| `v0.16.18`           | `--set global.fips=true`   |
| `v0.14.14`           | None                       |
| `v0.12.29`           | None                       |

Chart version `v0.16.18` ignores `global.fipsMode`. Chart version `v0.14.14` has no FIPS setting, and upstream publishes
no FIPS images for it. To run the FIPS variant of this image with it, add `--set podgrouper.image.tag=v0.14.14-fips`.
Chart `v0.12.29` has no FIPS setting either; see *Chart version v0.12.29* below.

### Chart version v0.12.29

Chart `v0.12.29` does not read `podgrouper.image.name` or `podgrouper.image.tag`. Its `kai-config` template has no
podGrouper section, and the operator starts podgrouper from `<global.registry>/podgrouper:<operator tag>`, which is
`v0.12.29` by default. Copy this image to that path, and copy the other images the chart runs for this version:

```bash
$ docker buildx imagetools create \
  --tag <your-namespace>/podgrouper:v0.12.29 \
    dhi.io/kai-scheduler-podgrouper:v0.12.29
$ for image in operator admission binder scheduler podgroupcontroller queuecontroller \
    resourcereservation nodescaleadjuster scalingpod crd-upgrader; do
    docker buildx imagetools create \
      --tag <your-namespace>/$image:v0.12.29 \
      ghcr.io/kai-scheduler/kai-scheduler/$image:v0.12.29
  done
```

Install the chart with the same pull secret and security context as above, and leave out the podgrouper image settings:

```bash
$ helm install kai-scheduler oci://ghcr.io/kai-scheduler/kai-scheduler/kai-scheduler \
  --version v0.12.29 --namespace kai-scheduler \
  --set global.registry=<your-namespace> \
  --set 'global.imagePullSecrets[0].name=mirror-pull-secret' \
  --set global.securityContext.runAsUser=65532 \
  --set global.securityContext.runAsGroup=65532
```

The path `<your-namespace>/podgrouper:v0.12.29` holds one podgrouper image, and this chart version has no setting that
selects a variant. To run another variant, copy it to that path in place of the Debian runtime image, with the first
command above:

- Alpine: `dhi.io/kai-scheduler-podgrouper:0.12.29-alpine3.24`
- Alpine FIPS: `dhi.io/kai-scheduler-podgrouper:0.12.29-alpine3.24-fips`
- Debian FIPS: `dhi.io/kai-scheduler-podgrouper:v0.12.29-fips`

## Common kai-scheduler-podgrouper use cases

### Group a workload's pods

Podgrouper acts on pods whose `schedulerName` is `kai-scheduler`. It annotates each pod with `pod-group-name`, which
identifies the PodGroup used by the KAI scheduler. This Job uses the `default-queue` queue that the chart creates and
needs a pull secret for `dhi.io` in its namespace:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-demo
  labels:
    kai.scheduler/queue: default-queue
spec:
  parallelism: 2
  completions: 2
  template:
    spec:
      schedulerName: kai-scheduler
      restartPolicy: Never
      imagePullSecrets:
        - name: dhi-pull-secret
      containers:
        - name: main
          image: dhi.io/busybox:1
          command: ["sleep", "30"]
```

```bash
$ kubectl create secret docker-registry dhi-pull-secret \
  --docker-server=dhi.io --docker-username=<username> --docker-password=<token>
$ kubectl apply -f batch-demo.yaml
$ kubectl get podgroups
$ kubectl get pods -l job-name=batch-demo \
  -o custom-columns='NAME:.metadata.name,PODGROUP:.metadata.annotations.pod-group-name'
```

On KAI 0.14 and later, both pods show the name of the same PodGroup. On KAI 0.12, each pod shows a different PodGroup;
batch Job pods are scheduled independently, as described in the
[upstream 0.12 batch guide](https://github.com/kai-scheduler/KAI-scheduler/blob/v0.12.29/docs/batch/README.md).

## Non-hardened images vs. Docker Hardened Images

- The entry point `/workspace/app`, the working directory `/workspace` and the nonroot user `65532` are the same as in
  the upstream image. The KAI operator runs podgrouper as user `10000` unless `global.securityContext` sets another
  user, so the installation above sets `65532`.
- Tags have no `v` prefix. The Debian 13 runtime and FIPS variants also publish `v<version>` and `v<version>-fips`.
- FIPS variants exist for every version, including 0.14, for which upstream publishes none. Their binary is built with
  the Go Cryptographic Module v1.0.0 and runs in FIPS 140-3 mode by default.

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
