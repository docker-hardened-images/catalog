## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this cdi-uploadserver image

This Docker Hardened CDI Upload Server image is a component of the
[Containerized Data Importer (CDI)](https://github.com/kubevirt/containerized-data-importer) project from KubeVirt.

- `cdi-uploadserver`: CDI Upload Server handles the upload of virtual machine disk images into persistent volume claims

CDI is designed to work with Kubernetes and KubeVirt. The cdi-uploadserver is one of several CDI components and is
typically deployed by the CDI operator as part of a full CDI installation.

### Run the cdi-uploadserver container

The CDI Upload Server is designed to run within a Kubernetes cluster as part of the CDI operator deployment. Running it
standalone requires Kubernetes API access and proper configuration.

To display help information:

```bash
docker run --rm dhi.io/cdi-uploadserver:<tag> -h
```

### Deploy CDI in Kubernetes

The recommended way to deploy CDI (including cdi-uploadserver) is using the official CDI operator manifests. To use the
Docker Hardened cdi-uploadserver image, you need to modify the operator's UPLOAD_SERVER_IMAGE environment variable.

1. Download the CDI operator manifest:

```bash
curl -LO https://github.com/kubevirt/containerized-data-importer/releases/download/v1.64.0/cdi-operator.yaml
```

2. Replace the upload server image reference:

```bash
sed -i 's|quay.io/kubevirt/cdi-uploadserver:v1.64.0|dhi.io/cdi-uploadserver:<tag>|g' cdi-operator.yaml
```

3. Apply the operator manifest:

```bash
kubectl apply -f cdi-operator.yaml
```

4. Create the CDI custom resource to trigger the deployment:

```bash
kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.64.0/cdi-cr.yaml
```

5. Verify the deployment:

```bash
kubectl get pods -n cdi
```

> **Note:** The dev variants of this image run as root. The default CDI operator manifests include `runAsNonRoot: true`
> in the security context, which prevents dev variants from running.

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
base image in your existing Dockerfile to a Docker Hardened Image.

| Item               | Migration note                                                                                                   |
| :----------------- | :--------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                        |
| Package management | Non-dev images don't contain package managers. Use package managers only in images with a `dev` tag.             |
| Non-root user      | By default, non-dev images run as the nonroot user. Ensure files are accessible to the nonroot user.             |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                 |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default.                                             |
| Ports              | Non-dev images run as nonroot. Configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points. Inspect and update your Dockerfile if necessary.         |
| No shell           | Non-dev images don't contain a shell. Use dev images in build stages and copy artifacts to runtime.              |

## Troubleshoot migration

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
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
