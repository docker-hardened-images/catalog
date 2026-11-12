## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About this forklift-operator-bundle image

This Docker Hardened forklift-operator-bundle image is an
[Operator Lifecycle Manager (OLM)](https://olm.operatorframework.io/) bundle for the Forklift operator, the upstream
project behind Red Hat Migration Toolkit for Virtualization (MTV). It includes:

- `/manifests`: The operator's `ClusterServiceVersion`, CRDs and `ClusterRole`, generated from the upstream source with
  `kustomize` and `operator-sdk generate bundle`. Every component image reference in the `ClusterServiceVersion` points
  at its Docker Hardened Images counterpart (for example `dhi.io/forklift-controller:2`).
- `/metadata`: The OLM `annotations.yaml` declaring the bundle's package (`forklift-operator`), channel, and manifest
  locations.

The image has no entrypoint, command, or binaries: OLM unpacks it by running the image with a copy helper it injects,
which copies `/manifests` and `/metadata` out. The image carries the debian-13 runtime baseline packages the catalog
ships (OS identification files, certificate bundle, timezone data); none of them execute.

### Inspect the bundle contents

The image has no runnable entrypoint of its own, but its contents can be extracted with `docker create` and `docker cp`.
Because the image declares no command, `docker create` needs a placeholder command argument; it is never executed:

```console
$ docker create --name forklift-bundle dhi.io/forklift-operator-bundle:<tag> true
$ docker cp forklift-bundle:/manifests ./manifests
$ docker cp forklift-bundle:/metadata ./metadata
$ docker rm forklift-bundle
```

Validate the extracted bundle with `operator-sdk`, using the same optional suite the image's tests enforce:

```console
$ operator-sdk bundle validate ./ --select-optional suite=operatorframework
```

### Install the operator with OLM

Operator bundles are consumed through an OLM catalog. `opm` renders this bundle into a File-Based Catalog of your own:

```console
$ mkdir -p my-catalog
$ opm render dhi.io/forklift-operator-bundle:<tag> --output=yaml >> my-catalog/catalog.yaml
```

`opm render` emits the `olm.bundle` entry only; the catalog also needs an `olm.package` entry named `forklift-operator`
and an `olm.channel` entry for the channel the image's `operators.operatorframework.io.bundle.channels.v1` label names
(`docker inspect` shows it) that lists the bundle before OLM serves it. The published `dhi.io/forklift-operator-index`
catalog serves upstream's `mtv-operator` package and does not include this bundle.

The operator and every component image the `ClusterServiceVersion` names live on `dhi.io` behind authentication, and
their pods run under ServiceAccounts that OLM creates during the install (`forklift-operator`, `forklift-controller`,
`forklift-api`, `forklift-populator-controller`) or under `default`. Configure the `dhi.io` credential cluster-wide
where you can (the global pull secret on OpenShift, or the node-level registry credentials of your distribution); a
namespace pull secret only reaches pods whose ServiceAccount lists it (see
[Use with Kubernetes](https://docs.docker.com/dhi/how-to/k8s/) for creating the secret).

For quick iteration on a cluster running OLM, `operator-sdk` installs the bundle directly; its pull secret covers the
bundle image only. Without a cluster-wide credential the operator pod cannot pull until its ServiceAccount lists the
secret, so `run bundle` reports a timeout while waiting for it (the objects it created stay in place); the two commands
after it give the accounts OLM created the secret and restart the operator, which completes the install:

```console
$ kubectl create namespace konveyor-forklift
$ kubectl create secret docker-registry dhi-pull --docker-server=dhi.io --docker-username=<user> --docker-password=<token> --namespace konveyor-forklift
$ kubectl patch serviceaccount default --namespace konveyor-forklift -p '{"imagePullSecrets":[{"name":"dhi-pull"}]}'
$ operator-sdk run bundle dhi.io/forklift-operator-bundle:<tag> --namespace konveyor-forklift --pull-secret-name dhi-pull
$ for account in forklift-operator forklift-controller forklift-api forklift-populator-controller; do kubectl patch serviceaccount $account --namespace konveyor-forklift -p '{"imagePullSecrets":[{"name":"dhi-pull"}]}'; done
$ kubectl rollout restart deployment/forklift-operator --namespace konveyor-forklift
```

Once the operator is installed, create a `ForkliftController` resource to deploy Forklift itself:

```yaml
apiVersion: forklift.konveyor.io/v1beta1
kind: ForkliftController
metadata:
  name: forklift-controller
  namespace: konveyor-forklift
spec: {}
```

```console
$ kubectl apply -f forkliftcontroller.yaml
```

### Component images

The `ClusterServiceVersion` hands the operator every component image through environment variables (`CONTROLLER_IMAGE`,
`API_IMAGE`, `VALIDATION_IMAGE` and so on), all pointing at Docker Hardened Images repositories. `VIRT_V2V_IMAGE_XFS`
names the same `dhi.io/forklift-virt-v2v:2` image as `VIRT_V2V_IMAGE`, because the catalog has no XFS-specific
converter. Installs that mirror Docker Hardened Images into their own repositories point the components at the mirror
through the `*_fqin` fields of the `ForkliftController` spec (`controller_image_fqin`, `ova_proxy_fqin` and so on); the
operator image itself is the one the `ClusterServiceVersion` names. The `Hook` sample in the CSV's `alm-examples` keeps
upstream's `quay.io/konveyor/hook-runner` image, because the catalog has no counterpart; hooks are optional and the
sample is a template to edit.

### Non-OpenShift clusters

Forklift targets clusters with KubeVirt installed. On non-OpenShift Kubernetes, OLM itself must be
[installed first](https://olm.operatorframework.io/docs/getting-started/) together with
[cert-manager](https://cert-manager.io/docs/installation/), which the operator uses to issue the component serving
certificates, and UI-plugin features tied to the OpenShift console are not available.

Deleting the `ForkliftController` on such a cluster does not finish on its own: the operator's finalizer tries to remove
an OpenShift `ConsolePlugin`, fails on the missing API and leaves the resource with a `deletionTimestamp`. Clear the
finalizer by hand and Kubernetes garbage-collects the components the operator created:

```console
$ kubectl patch forkliftcontroller forklift-controller --namespace konveyor-forklift --type merge -p '{"metadata":{"finalizers":null}}'
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
