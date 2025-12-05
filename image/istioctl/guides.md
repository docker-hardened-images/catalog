## How to use this image

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository** > **Mirror to
repository**, and then follow the on-screen instructions.

## Start an Istioctl image

The Istioctl image provides the `istoctl` binary for managing Istio installations. It is designed as a client-side CLI
tool.

Replace `<your-namespace>` with your organization's namespace and `<tag>` with the image variant you want to use.

```bash
kubectl run istioctl --image=<your-namespace>/dhi-istioctl:<tag> \
  --rm -it --restart=Never -- --help
```

## Common Istioctl use cases

### Generate Istio installation manifests

Use istioctl to generate Istio manifests for review before installation:

```bash
kubectl run istioctl --image=<your-namespace>/dhi-istioctl:<tag> \
  --rm -it --restart=Never -- manifest generate
```

## Docker Official Images vs. Docker Hardened Images

Key differences specific to the Istioctl DHI:

- **Security hardening**: Runs as a nonroot user by default
- **Minimal tooling**: No shell or package manager in runtime images
- **SBOM included**: Built-in software bill of materials for vulnerability tracking

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Runtime variants run as a nonroot
user without a shell or package manager.

To view the image variants and get more information about them, select the **Tags** tab for this repository.

## Migrate to a Docker Hardened Image

To migrate to the Docker Hardened Istioctl image, update your image references:

```yaml
image: <your-namespace>/dhi-istioctl:<tag>
```

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

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

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
