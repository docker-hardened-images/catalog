## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Notation Hardened image

This image contains Notation, a CLI tool for signing and verifying OCI artifacts, designed to secure container images
and related artifacts in registries and CI/CD pipelines. The container entrypoint is the `notation` binary. When run
without arguments or with `--help`, it prints usage information, and subcommands such as `sign` and `verify` provide the
primary functionality.

Notation supports core capabilities like artifact signing, signature verification, trust policy enforcement, and key or
certificate management, while integrating with registry plugins for cloud key vaults. Notation works with OCI-compliant
registries that support the Referrers API and can be used in Kubernetes admission policies or supply chain workflows.
This makes the image a portable way to run Notation inside a container, simplifying artifact signing and verification
without installing the CLI directly on the host.

Common subcommands include `notation sign <artifact>`, `notation verify <artifact>`, `notation cert add`, and
`notation policy show`.

## Start a Notation instance.

Run the container with `docker run` to start a Notation CLI instance.

```console
$ docker run --rm -it \
  dhi.io/notation:<tag> \
  --help
```

The container entrypoint is `notation`, which defaults to command-line mode. By default, it runs the CLI to execute
commands like `sign` and `verify`.

To persist configuration (e.g., trust policies, keys), mount a volume instead of using `--rm`. The following example
uses /home/nonroot/.config/notation as the default configuration directory:

```console
$ docker run -it \
  -v notation-data:/home/nonroot/.config/notation \
  dhi.io/notation:<tag> \
  verify <artifact-reference>
```

This allows you to keep configuration and keys after the container stops. Once running, you can use `notation sign` to
sign OCI artifacts or `notation verify` to check signatures in your supply chain.

For more advanced usage, refer to the [Notation documentation](https://notaryproject.dev/docs/).

## Common Notation use cases

### Signing container images in CI/CD

Notation can be added to build pipelines to automatically sign container images before pushing them to a registry. This
ensures every artifact has a verifiable signature, giving developers and operators confidence in the integrity of the
images they deploy.

### Verifying artifacts in Kubernetes

Kubernetes clusters can use Notation to verify image signatures at admission time through policy engines like Kyverno or
Gatekeeper. This prevents unsigned or tampered images from being scheduled, improving supply chain security in
multi-tenant or production environments.

### Managing trust policies and keys

Operators can configure Notation with trust policies that define which certificate authorities or keys are valid. This
helps organizations standardize signing practices across teams and enforce consistent trust boundaries.

### Securing non-image OCI artifacts

In addition to container images, Notation can sign and verify other OCI artifacts such as Helm charts or SBOMs. This
allows operators to maintain a consistent verification workflow across multiple artifact types used in Kubernetes
deployments.

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Notation                     | Docker Hardened Notation                                   |
| --------------- | ----------------------------------------- | ---------------------------------------------------------- |
| Base image      | Alpine or Ubuntu-based                    | Debian hardened base                                       |
| Security        | Standard image with basic utilities       | Hardened build with security patches and security metadata |
| Shell access    | Shell available                           | No shell                                                   |
| Package manager | `apk` (Alpine) or `apt` (Ubuntu)          | No package manager                                         |
| User            | Runs as `root`.                           | Runs as non-root user.                                     |
| Data directory  | N/A (CLI tool, no persistent data needed) | N/A (stateless CLI tool)                                   |
| Build process   | Pre-compiled binaries                     | Built from source with verified commit                     |
| Attack surface  | 200+ utilities and tools                  | Only `notation` binary and CA certificates                 |
| Debugging       | Shell and standard Unix tools             | Use Docker Debug or image mount for troubleshooting        |
| SBOM            | Not included                              | Software Bill of Materials included                        |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                            |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the **Tags** tab for this repository. To view what packages are already installed in an image variant, select
   the **Tags** tab for this repository, and then select a tag.

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
