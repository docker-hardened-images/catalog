## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this GCP plugin image

This Docker Hardened image includes the Velero plugin for GCP, which adds support for using Google Cloud Storage as a
backup storage location for Velero. This image is referenced by Velero at install time (via `--plugins`) and is not run
directly as a long-lived process.

## Use the GCP plugin when installing Velero

Unlike other Docker Hardened Images, you don't run the Velero server directly with `docker run`. Instead, you use the
Velero CLI to install the server into your Kubernetes cluster. The `velero install` command deploys the Velero server
into the cluster using the specified images.

The `velero` image contains the `velero` binary, which acts as both the CLI and the server runtime. When you run
`velero install` with this image, the CLI runs locally and deploys the same hardened image as the server inside your
cluster.

The following example installs Velero with the GCP plugin. It assumes you already have a GCP project with a storage
bucket named `velero`.

```
docker run -it --rm \
  -v $(pwd)/gcp-credentials.json:/etc/gcp-credentials.json \
  -v $(pwd)/kube/config:/etc/kube-config \
  dhi.io/velero:<tag> \
  velero install \
    --image dhi.io/velero:<tag> \
    --plugins dhi.io/velero-plugin-for-gcp:<tag> \
    --provider gcp \
    --bucket velero \
    --secret-file /etc/gcp-credentials.json \
    --backup-location-config project=YOUR_PROJECT_ID \
    --kubeconfig /etc/kube-config
```

> [!NOTE]
>
> You can also use a standard Velero CLI binary (for example, one installed on your workstation) to install the hardened
> Velero image into your cluster. Just make sure the CLI and image versions are compatible, and provide the same flags
> as shown above to point to the hardened image and plugin images when running `velero install`.

# Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Velero                 | Docker Hardened Velero                              |
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
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/<image-name>:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

## Migrate to a Docker Hardened Image

Switching to the hardened Velero GCP plugin image does not require any special changes. You can use it as a drop-in
replacement for the standard `velero/velero-plugin-for-gcp` image in your existing workflows and configurations.

### Migration steps

1. Update your image reference. Replace the image reference in your Docker run command or Compose file:
   - From: `velero/velero-plugin-for-gcp:<tag>`
   - To: `dhi.io/velero-plugin-for-gcp:<tag>`
1. No configuration changes needed. All your existing environment variables, volume mounts, and network settings remain
   the same.

### General migration considerations

While the Velero-specific configuration requires no changes, be aware of these general differences in Docker Hardened
Images:

| Item            | Migration note                                                         |
| --------------- | ---------------------------------------------------------------------- |
| Shell access    | No shell in runtime variants, use Docker Debug for troubleshooting     |
| Package manager | No package manager in runtime variants                                 |
| Debugging       | Use Docker Debug or Image Mount instead of traditional shell debugging |

## Troubleshoot migration

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
