## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this KServe LocalModel Controller Hardened Image

This Docker Hardened KServe LocalModel Controller image includes the LocalModel controller component from KServe. The
LocalModel controller manages cluster-wide local model caching and storage, coordinating the efficient caching of
machine learning models across the cluster. It handles model loading, caching, and cleanup operations to improve
inference startup times and optimize storage resource utilization.

### Start a KServe LocalModel Controller instance

The KServe LocalModel Controller is typically deployed as part of a KServe installation in Kubernetes. To run it
standalone for testing, use the following command:

```bash
docker run --name kserve-localmodel-controller \
  -p 8080:8080 -p 8081:8081 -p 9443:9443 \
  dhi.io/kserve-localmodel-controller:<tag>
```

**Note**: The controller requires access to a Kubernetes cluster API to function properly. When running standalone
without cluster access, it will start and attempt to connect but will fail gracefully.

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened KServe LocalModel Controller | Docker Hardened KServe LocalModel Controller        |
| --------------- | ----------------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities       | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available            | No shell in runtime variants                        |
| Package manager | apt/apk available                         | No package manager in runtime variants              |
| User            | Runs as root by default                   | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities        | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging               | Use Docker Debug or Image Mount for troubleshooting |

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
  dhi.io/kserve-localmodel-controller:<tag> /dbg/bin/sh
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

Switching to the hardened KServe LocalModel Controller image does not require any special changes. You can use it as a
drop-in replacement for the standard KServe LocalModel Controller image in your existing Kubernetes deployments and
configurations. Note that the entry point for the hardened image may differ from the standard image, so ensure that your
commands and arguments are compatible.

### Migration steps

1. Update your image reference.

   Replace the image reference in your Kubernetes manifests or Helm values, for example:

   - From: `kserve/kserve-localmodel-controller:<tag>`
   - To: `dhi.io/kserve-localmodel-controller:<tag>`

1. All your existing command-line arguments, environment variables, port mappings, and network settings remain the same.

1. Test your migration and use the troubleshooting tips below if you encounter any issues.

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
