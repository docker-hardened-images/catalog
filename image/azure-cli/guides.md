## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/azure-cli:<tag>`
- Mirrored image: `<your-namespace>/dhi-azure-cli:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Getting started with Azure CLI

The image's entry point is `az`, so any arguments you pass after the image reference are handed directly to the Azure
CLI. Check the version:

```bash
docker run --rm dhi.io/azure-cli:<tag> version
```

Run any other Azure CLI command the same way, for example listing the built-in Azure clouds:

```bash
docker run --rm dhi.io/azure-cli:<tag> cloud list --output table
```

The image provides the `az` command and its Python runtime. For complete command, usage, and configuration
documentation, see the [upstream project](https://github.com/Azure/azure-cli).

### Configuration directory

Azure CLI keeps its configuration, logs, sign-in token cache, and telemetry state in a config directory. This image sets
`AZURE_CONFIG_DIR=/azure` and creates that directory writable for the nonroot runtime user. To persist sign-in state and
configuration across container runs, mount a volume at `/azure`:

```bash
docker run --rm -v azure-cli-config:/azure dhi.io/azure-cli:<tag> config set core.output=table
```

That command writes `/azure/config` in the volume, so the setting is still in effect the next time you run the image
with the same volume mounted. Commands that talk to Azure need a sign-in first; see [Authentication](#authentication).

### Authentication

Most Azure CLI commands require you to sign in first. In a container, non-interactive sign-in methods are usually the
most convenient:

- **Service principal:** supply the credentials at runtime and sign in with `az login --service-principal`.

  ```bash
  docker run --rm -v azure-cli-config:/azure \
    -e AZURE_CLIENT_ID -e AZURE_CLIENT_SECRET -e AZURE_TENANT_ID \
    dhi.io/azure-cli:<tag> \
    login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID"
  ```

- **Managed identity:** when running on Azure infrastructure, sign in with `az login --identity`.

The credentials above are secrets and must be provided at runtime; they are never baked into the image. After a
successful sign-in, reuse the same `/azure` volume so subsequent commands stay authenticated.

## Non-hardened images vs. Docker Hardened Images

### Entry point

The upstream `mcr.microsoft.com/azure-cli` image has no entry point and starts a shell by default, so commands are
written with a leading `az`, for example `docker run mcr.microsoft.com/azure-cli az group list`. This image sets `az` as
the entry point, so drop the leading `az` and pass the subcommand directly:

```bash
docker run --rm dhi.io/azure-cli:<tag> group list
```

Running the image with no arguments prints `az --help`. Because `az` is the entry point on every variant, including
`dev`, open a shell in the dev variant by overriding it:

```bash
docker run --rm -it --entrypoint bash dhi.io/azure-cli:<tag>-dev
```

### Configuration location

The upstream `mcr.microsoft.com/azure-cli` image runs as root and leaves `AZURE_CONFIG_DIR` unset, so `az` uses its
default of `$HOME/.azure` — `/root/.azure` in that image. This image runs as the nonroot user and sets
`AZURE_CONFIG_DIR=/azure` instead.

If you are migrating a mount that targeted the upstream path, retarget it. A `-v azcfg:/root/.azure` mount is not an
error in this image, it is simply ignored: `az` reads `/azure`, finds no credentials there, and reports that you are not
signed in.

```bash
# Upstream
docker run --rm -v azcfg:/root/.azure mcr.microsoft.com/azure-cli az account show

# This image
docker run --rm -v azcfg:/azure dhi.io/azure-cli:<tag> account show
```

The contents are compatible, so a volume populated by the upstream image works once it is mounted at `/azure`. Note that
the files must be readable by the nonroot user (uid 65532).

### Commands that shell out

The runtime variant has no shell and no package manager. Some `az` subcommands run other programs in the container, and
those will not work in the runtime variant unless you add the program yourself. Examples include `az aks` commands that
invoke `kubectl`, `az ssh`, and flows that call `git`. For these workflows, use the `dev` variant, which includes a
shell and package manager, or add the required tools in a build stage alongside `az`.

### Extensions

`az extension add` works in both variants, because `pip` is kept in the payload venv for exactly that purpose.
Extensions install into `$AZURE_CONFIG_DIR/cliextensions`, so mount `/azure` if you want them to survive the container.
Extensions that publish prebuilt wheels — the common case — need nothing further.

An extension that compiles on install needs a C toolchain, and neither variant ships one: the `dev` variant has `bash`,
`apt-get` and `dpkg`, but no compiler. Install the build dependencies there first, in a build stage:

```dockerfile
FROM dhi.io/azure-cli:<tag>-dev
RUN apt-get update && apt-get install -y --no-install-recommends gcc python3-dev \
 && az extension add --name <extension>
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

  For Azure CLI specifically, the validated module backs the system OpenSSL that Python's `ssl` links, which is the path
  `az` uses for TLS to Azure endpoints. The bundled `cryptography` library ships its own statically linked OpenSSL, so
  cryptographic primitives that `az` drives through `cryptography` rather than through `ssl` do not run in the validated
  module.

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
