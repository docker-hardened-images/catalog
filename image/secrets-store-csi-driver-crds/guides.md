## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Secrets Store CSI Driver CRDs instance

Secrets Store CSI Driver CRDs is a packaging image from the
[Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io) project, a Kubernetes SIG project that mounts
secrets from external stores into pods. The image bundles the driver's CustomResourceDefinitions along with `kubectl` to
apply them. It normally runs as a Kubernetes Job or an init container, so the definitions are registered before the
driver DaemonSet starts.

### What's included in this Secrets Store CSI Driver CRDs image

- `kubectl`, used to apply the bundled definitions
- `/crds/secrets-store.csi.x-k8s.io_secretproviderclasses.yaml`, the `SecretProviderClass` definition
- `/crds/secrets-store.csi.x-k8s.io_secretproviderclasspodstatuses.yaml`, the `SecretProviderClassPodStatus` definition

This is one of two images from the Secrets Store CSI Driver project:

- **secrets-store-csi-driver-crds** for CRD packaging and installation (this image)
- **secrets-store-csi-driver** for the driver itself, which runs as a DaemonSet

The SBOM records `kube-apiserver-1.36` as the source package that `kubectl` is built from, on both distros. That is a
build-time attribution only. The Kubernetes API server is not installed in this image. Besides `kubectl`, the runtime
variants ship only `ca-certificates-bundle`, `tzdata`, and a base layout package, which is `base-files` on Debian and
`alpine-baselayout-data` on Alpine.

For the following examples, replace `<tag>` with the image variant you want to run. In examples that pair this image
with the driver, `<crds-tag>` refers to this image's tag and `<driver-tag>` refers to the secrets-store-csi-driver
image's tag.

Run the following command to verify the image and display kubectl help information:

```
$ docker run --rm dhi.io/secrets-store-csi-driver-crds:<tag>
```

To list the CRD files bundled in the image:

```
$ docker run --rm --entrypoint ls dhi.io/secrets-store-csi-driver-crds:<tag>-dev /crds
```

## Common Secrets Store CSI Driver CRDs use cases

### Install the CRDs into a Kubernetes cluster

The main use for this image is applying the definitions to a cluster. As a Job, it runs `kubectl apply` once and exits:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: secrets-store-csi-driver-crds-install
spec:
  template:
    spec:
      serviceAccountName: secrets-store-csi-driver-crds
      containers:
        - name: crds
          image: dhi.io/secrets-store-csi-driver-crds:<tag>
          args:
            - apply
            - -f
            - /crds
      restartPolicy: OnFailure
```

The service account needs permission to create and update `customresourcedefinitions` in the `apiextensions.k8s.io` API
group.

### Use as an init container

You can run the image as an init container so the definitions exist before the driver starts:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: secrets-store-csi-driver
spec:
  template:
    spec:
      initContainers:
        - name: crds
          image: dhi.io/secrets-store-csi-driver-crds:<crds-tag>
          args:
            - apply
            - -f
            - /crds
      containers:
        - name: secrets-store
          image: dhi.io/secrets-store-csi-driver:<driver-tag>
          # ... other configuration
```

### Deploy via Helm with a hardened CRDs image

The upstream chart installs the definitions with a hook that uses this image. Point it at the hardened image:

```
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts

helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --set linux.crds.image.repository=dhi.io/secrets-store-csi-driver-crds \
  --set linux.crds.image.tag=<tag>
```

### Check that the definitions registered

After the Job or hook completes, confirm both definitions are established:

```
$ kubectl get crd secretproviderclasses.secrets-store.csi.x-k8s.io \
    secretproviderclasspodstatuses.secrets-store.csi.x-k8s.io
```

For deployment instructions and configuration options, see the
[official Secrets Store CSI Driver documentation](https://secrets-store-csi-driver.sigs.k8s.io).

## Non-hardened images vs Docker Hardened Images

The hardened image ships the same two definitions as the upstream image, at the same `/crds` path, so the usual
`apply -f /crds` invocation is unchanged.

Two things differ. The upstream image sets its entry point to the absolute path `/kubectl`, while the hardened image
resolves `kubectl` through `PATH`. A symlink at `/kubectl` is kept so the absolute path still works if you override the
entry point. The upstream image also downloads a fixed kubectl build at image build time, whereas the hardened image
installs kubectl from a Docker Hardened package that is patched and rebuilt on its own schedule, so its version will
usually be newer than upstream's.

### Key differences

| Feature         | Non-hardened image                  | Docker Hardened image                               |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-secrets-store-csi-driver-crds \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/secrets-store-csi-driver-crds:<tag>
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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

In the FIPS variants of this image, `kubectl` comes from the FIPS build of the Docker Hardened kubectl package, which
links the validated Go cryptographic module, and the OpenSSL FIPS provider is installed for STIG. Note that the
Kubernetes client libraries negotiate X25519 for TLS 1.3 key exchange with the API server. The default FIPS posture is
the lenient one, which permits that key exchange while the validated module covers the rest.

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
| Entry point        | The entry point for this image is `kubectl`, resolved through `PATH`, with a compatibility symlink at `/kubectl`. Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                |
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
