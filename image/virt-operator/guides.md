## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this virt-operator image

This Docker Hardened Virt Operator image is a component of the [KubeVirt](https://github.com/kubevirt/kubevirt) project.

- `virt-operator`: Virt Operator deploys and manages the KubeVirt virtualization infrastructure in Kubernetes

KubeVirt extends Kubernetes with virtualization capabilities. The virt-operator is one of several KubeVirt components
typically deployed by the KubeVirt operator as part of a full installation.

### Run the virt-operator container

The Virt Operator is designed to run within a Kubernetes cluster as part of the KubeVirt operator deployment.

To display help information:

```bash
docker run --rm dhi.io/virt-operator:<tag> --help
```

### Deploy KubeVirt in Kubernetes

The recommended way to deploy KubeVirt (including virt-operator) is using the official KubeVirt operator manifests.
Replace `<tag>` with the KubeVirt release that matches your image line (for example, `v1.5.3` for 1.5.x images, `v1.6.4`
for 1.6.x images, or `v1.7.2` for 1.7.x images).

1. Install the KubeVirt operator:

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/<tag>/kubevirt-operator.yaml
```

2. Create the KubeVirt custom resource:

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/<tag>/kubevirt-cr.yaml
```

3. Verify the deployment:

```bash
kubectl get pods -n kubevirt
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name. These images typically:

  - Run as the root user
  - Include a shell and package manager

- FIPS variants include `fips` in the variant name and tag. They use cryptographic modules validated under FIPS 140.

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
