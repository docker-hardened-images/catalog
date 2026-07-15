## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/ceph-csi-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-ceph-csi-operator:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Ceph CSI Operator image

This Docker Hardened Ceph CSI Operator image includes:

- The Ceph CSI Operator controller manager, which reconciles OperatorConfig and Driver custom resources into the Ceph
  CSI controller and node plugin workloads
- Support for the RBD, CephFS, NFS, and NVMe-oF driver types

The operator only creates and manages Kubernetes resources; the storage data path is served by the separate Ceph CSI
driver image.

## Start a Ceph CSI Operator instance

The Ceph CSI Operator is a Kubernetes operator. It cannot run as a standalone container outside of Kubernetes as it
requires access to the Kubernetes API and the `csi.ceph.io` custom resources. The operator also requires the
`OPERATOR_NAMESPACE` environment variable to be set; in Kubernetes this is injected from the pod namespace.

### View available flags

Run the following command to view the Ceph CSI Operator flags. Replace `<tag>` with the image variant you want to run.
The `OPERATOR_NAMESPACE` variable must be set or the operator exits before parsing flags.

```
$ docker run --rm -e OPERATOR_NAMESPACE=ceph-csi-operator-system dhi.io/ceph-csi-operator:<tag> --help
```

### Deploy to Kubernetes

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

Apply the upstream Ceph CSI Operator install manifests, overriding the controller image so it points to the DHI image.
Download the release manifests for the version you are deploying from the
[ceph-csi-operator releases](https://github.com/ceph/ceph-csi-operator/releases), then install the CRDs and the
operator:

```
$ kubectl create -f crd.yaml
$ kubectl create -f operator.yaml
```

Set the DHI image on the operator Deployment:

```
$ kubectl set image -n ceph-csi-operator-system \
   deployment/ceph-csi-operator-controller-manager \
   manager=dhi.io/ceph-csi-operator:<tag>
```

Verify the deployment:

```
$ kubectl rollout status -n ceph-csi-operator-system deployment/ceph-csi-operator-controller-manager
```

## Common Ceph CSI Operator use cases

### Deploy an RBD CSI driver

Once the operator is running, create a Driver custom resource. The operator reconciles it into a controller Deployment
and a node plugin DaemonSet. The Driver name must end in one of the supported driver types (`rbd`, `cephfs`, `nfs`, or
`nvmeof`) followed by `.csi.ceph.com`:

```yaml
apiVersion: csi.ceph.io/v1
kind: Driver
metadata:
  name: rbd.csi.ceph.com
  namespace: ceph-csi-operator-system
spec:
  log:
    verbosity: 1
```

Apply it and confirm the operator created the driver workloads:

```
$ kubectl apply -f driver.yaml
$ kubectl get daemonset,deployment -n ceph-csi-operator-system
```

### Adjust operator-wide defaults

Cluster-wide defaults such as log rotation and image overrides are configured through the OperatorConfig custom
resource, named `ceph-csi-operator-config` by default:

```yaml
apiVersion: csi.ceph.io/v1
kind: OperatorConfig
metadata:
  name: ceph-csi-operator-config
  namespace: ceph-csi-operator-system
spec:
  log:
    verbosity: 1
```

## Official image vs Docker Hardened Image (DHI)

| Feature         | Upstream (`quay.io/cephcsi/ceph-csi-operator`) | DHI (`dhi.io/ceph-csi-operator`)   |
| :-------------- | :--------------------------------------------- | :--------------------------------- |
| User            | nonroot (65532)                                | nonroot (65532)                    |
| Shell           | No                                             | No (runtime) / Yes (dev)           |
| Package manager | No                                             | No (runtime) / Yes (dev)           |
| FIPS variant    | No                                             | Yes                                |
| STIG compliance | No                                             | Yes (100%)                         |
| Base OS         | Distroless                                     | Docker Hardened Images (Debian 13) |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a multi-stage
Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

The Ceph CSI Operator Docker Hardened Image is available in all variant types: runtime, dev, FIPS, and FIPS-dev. To view
the image variants and get more information about them, select the **Tags** tab for this repository, and then select a
tag.

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

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

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

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
