## How to use this image

All examples use the public image. If you have mirrored the image to your own namespace, replace `dhi.io/nvflare` with
your mirrored reference.

Authenticate before pulling:

```bash
docker login dhi.io
```

### What's included in this nvflare image

- `nvflare` CLI — entry point for federated learning operations
- Full NVFlare Python runtime with Kubernetes support (`.[K8S]` extras)
- Python virtual environment at `/opt/nvflare`

### Run the nvflare container

Check the installed version:

```bash
docker run --rm dhi.io/nvflare:<tag> --version
```

Show the help output:

```bash
docker run --rm dhi.io/nvflare:<tag> --help
```

### Quick-start with NVFlare POC

NVFlare 2.8.0 manages federated learning systems via the `poc` command. The `start_server`/`start_client` subcommands
from earlier releases are not present in this version.

Prepare a local proof-of-concept environment with one server and two clients:

```bash
mkdir -p /path/to/poc
sudo chown 65532:65532 /path/to/poc

docker run --rm -it \
  -v /path/to/poc:/poc \
  -e NVFLARE_POC_WORKSPACE=/poc/ws \
  dhi.io/nvflare:<tag> \
  poc prepare -n 2
```

The workspace is written to `/path/to/poc/ws` on the host. The `chown` step is required because the container runs as
uid 65532.

Refer to the
[NVFlare POC documentation](https://nvflare.readthedocs.io/en/2.8.0/user_guide/nvflare_cli/poc_command.html) for full
POC startup and provisioning guides.

### Kubernetes deployment

NVFlare is designed for Kubernetes-native federated learning. Refer to the
[NVFlare documentation](https://nvidia.github.io/NVFlare/) for full deployment guides using the provisioning tool and
Helm charts.

### Troubleshooting

**Container exits immediately**

The image entrypoint is `/opt/nvflare/bin/nvflare`. Pass a valid subcommand such as `--version` or `--help` to verify
the image works. Note that `start_server` and `start_client` are not valid subcommands in NVFlare 2.8.0; use
`nvflare poc` or a provisioned startup kit instead.

**Entrypoint differs from upstream**

Upstream `nvflare/nvflare` images default to `python3` (no entrypoint). This hardened image defaults to the `nvflare`
CLI. CLI workflows such as `poc prepare` and `simulator` work without change. If you previously ran Python scripts or an
interactive interpreter against the upstream image, override the entrypoint or use a `dev` tag:

```bash
docker run --rm --entrypoint /opt/nvflare/bin/python3 dhi.io/nvflare:<tag> -c "import nvflare; print(nvflare.__version__)"
docker run --rm --entrypoint /opt/nvflare/bin/python3 dhi.io/nvflare:<tag>-dev my_script.py
```

**Permission denied on mounted volumes**

The container runs as uid 65532. Ensure mounted directories are readable by that user:

```bash
chown -R 65532:65532 /path/to/workspace
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
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
| Entry point        | Upstream `nvflare/nvflare` defaults to `python3`. This image defaults to `/opt/nvflare/bin/nvflare`. Pass `nvflare` CLI args directly, or use `--entrypoint /opt/nvflare/bin/python3` (or a `dev` tag) when you need a Python interpreter or script.                                                                         |
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

Upstream `nvflare/nvflare` has no entrypoint and defaults to `python3`. This hardened image sets the entrypoint to
`/opt/nvflare/bin/nvflare`, so container arguments are passed to the NVFlare CLI. For a Python interpreter or script,
override with `--entrypoint /opt/nvflare/bin/python3` or use a `dev` tag. Use `docker inspect` to confirm the entrypoint
when migrating Dockerfiles or orchestration manifests.
