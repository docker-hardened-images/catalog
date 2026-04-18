## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Placement image

This Docker Hardened open-cluster-management-placement image includes:

- The `placement` binary built from the official Open Cluster Management releases
- The entrypoint is the placement binary at `/usr/local/bin/placement`
- The default command is `controller`, so `docker run` with no arguments starts the Placement Scheduling Controller
- Configuration via command-line flags

### Run the Placement controller

The Placement controller is a Kubernetes controller and requires a running Kubernetes cluster with the Open Cluster
Management hub installed. It cannot be run standalone outside of a Kubernetes environment.

### Deploy to a Kubernetes cluster

The Placement controller is deployed by the OCM cluster-manager operator. Upstream's Deployment template passes the
binary path as `args[0]` (`["/placement", "controller", ...]`). The hardened image has
`ENTRYPOINT=/usr/local/bin/placement`, so that leading `/placement` arg becomes a subcommand and the container fails
with `unknown command "/placement"`. Swap the image and drop just that first arg — hosted mode and any other flags the
operator threads through (`--kubeconfig=...`, feature gates, etc.) are preserved:

```bash
# Replace <tag> with the image variant you want to run
kubectl patch deployment/cluster-manager-placement-controller \
  -n open-cluster-management-hub \
  --type=json \
  -p='[
    {"op":"replace","path":"/spec/template/spec/containers/0/image","value":"dhi.io/open-cluster-management-placement:<tag>"},
    {"op":"remove","path":"/spec/template/spec/containers/0/args/0"}
  ]'
```

The cluster-manager operator reconciles this Deployment and may revert the patch. For a lasting swap, update the
`placementImagePullSpec` on the `ClusterManager` CR and override the operator's Deployment template, or manage the
Placement Deployment outside the operator.

If you renamed the ClusterManager CR, adjust the deployment name and namespace accordingly.

### Verify the deployment

```bash
kubectl get pods -n open-cluster-management-hub -l app=cluster-manager-placement-controller
```

### Check the version

```bash
docker run --rm dhi.io/open-cluster-management-placement:<tag> --version
```

### Configuration

The Placement controller is configured via command-line flags. Use the `controller` subcommand to start the controller:

```bash
docker run --rm dhi.io/open-cluster-management-placement:<tag> controller --help
```

### Kubernetes deployment

For production deployments, use the Open Cluster Management operator to manage the Placement controller lifecycle. Refer
to the [Open Cluster Management documentation](https://open-cluster-management.io/docs/) for details.

### Non-hardened images vs Docker Hardened Images

| Feature         | Non-hardened (quay.io/open-cluster-management/placement) | Docker Hardened (dhi/open-cluster-management-placement) |
| --------------- | -------------------------------------------------------- | ------------------------------------------------------- |
| Base image      | Red Hat UBI Minimal                                      | Debian 13 hardened base                                 |
| User            | UID 10001                                                | Nonroot user (UID 65532)                                |
| Binary location | `/placement`                                             | `/usr/local/bin/placement`                              |
| Shell/utilities | Included                                                 | Not included (minimal attack surface)                   |
| CVE compliance  | Standard patching                                        | Near-zero CVEs with proactive remediation               |
| Provenance      | Not signed                                               | Signed with complete SBOM/VEX                           |

Docker Hardened Images prioritize security through minimalism. Runtime images don't contain a shell or package manager
to reduce attack surface. For debugging, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to
attach to containers with ephemeral debugging tools.

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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                               |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                               |

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

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
