## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this forklift-operator image

This Docker Hardened Forklift Operator image is the management component of the
[Forklift](https://github.com/kubev2v/forklift) VM migration toolkit for KubeVirt.

- `ansible-operator`: the Operator SDK ansible operator runtime that watches the `ForkliftController` custom resource
- the Ansible runtime: `ansible-core`, `ansible-runner`, and the `kubernetes.core`, `cloud.common`, and
  `operator_sdk.util` collections
- the Forklift operator role and watches configuration at `/app`, which render and apply the manifests for every other
  Forklift component

Unlike most hardened runtime images, this one ships `dash` and `coreutils`: Ansible's local connection executes every
module through `/bin/sh`, so the operator cannot run without a POSIX shell.

Forklift migrates virtual machines from VMware vSphere, oVirt, OpenStack, Hyper-V, EC2, and OVA sources to KubeVirt. The
operator deploys and manages the other Forklift components; it does not perform migrations itself.

### Run the forklift-operator container

The operator is designed to run inside a Kubernetes cluster. Running it standalone is useful mainly to verify the image
starts:

```bash
docker run --rm dhi.io/forklift-operator:<tag>
```

Without a cluster the operator logs an error that it cannot load an in-cluster configuration and exits. That is the
expected standalone behavior.

To check the versions of the bundled runtime:

```bash
docker run --rm --entrypoint /usr/local/bin/ansible-operator dhi.io/forklift-operator:<tag> version
```

### Ports

| Port   | Description                                        |
| ------ | -------------------------------------------------- |
| `6789` | Health probes at `/healthz` and `/readyz`          |
| `8443` | Metrics, overridable with `--metrics-bind-address` |

### Component image references

The operator resolves the image of every Forklift component from its `*_IMAGE` environment variable, and each variable
falls back to the matching `RELATED_IMAGE_*` variable that Operator Lifecycle Manager injects from the
ClusterServiceVersion. The full variable list and defaults live in the upstream role
(`operator/roles/forkliftcontroller/defaults/main.yml`) and the
[Forklift documentation](https://kubev2v.github.io/forklift-documentation/).

The operator image builds for amd64 and arm64, but the upstream component images it deploys are published for amd64
only, so on arm64 nodes the operator itself runs while the reconciled components must schedule on amd64 nodes.

The operator also reads `WATCH_NAMESPACE` to scope reconciliation and `APP_NAME` (default `forklift`) to prefix the
resources it creates. Feature toggles such as `feature_ui_plugin`, `feature_validation`, and `feature_volume_populator`
are set in the `ForkliftController` resource.

### Deploy Forklift in Kubernetes

Forklift is installed through Operator Lifecycle Manager: a `CatalogSource` pointing at a Forklift operator index feeds
OLM the ClusterServiceVersion that deploys this operator, and creating a `ForkliftController` resource then makes the
operator deploy the remaining components. See the
[Forklift documentation](https://kubev2v.github.io/forklift-documentation/) for installation instructions.

A minimal `ForkliftController` for a plain Kubernetes cluster looks like this. `k8s_cluster` defaults to `"false"`,
which enables OpenShift-specific resources such as Routes; omit it only when deploying on OpenShift.

```yaml
apiVersion: forklift.konveyor.io/v1beta1
kind: ForkliftController
metadata:
  name: forklift-controller
  namespace: konveyor-forklift
spec:
  k8s_cluster: "true"
  feature_ui_plugin: "false"
  feature_validation: "true"
  feature_volume_populator: "true"
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations.

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
