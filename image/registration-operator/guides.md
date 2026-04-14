## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/registration-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-registration-operator:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this registration-operator image

This Docker Hardened registration-operator image is a component of the
[Open Cluster Management (OCM)](https://github.com/open-cluster-management-io/ocm) project.

- The `registration-operator` binary built from the official OCM releases
- The image runs the `registration-operator` binary directly from `/usr/local/bin/registration-operator`
- Configuration via command-line flags

The registration-operator provides two operators:

- **Cluster Manager** (hub subcommand) — installs OCM foundational components on the hub cluster
- **Klusterlet** (klusterlet subcommand) — installs agent components on managed clusters

It is designed to run within a Kubernetes cluster to manage multi-cluster operations.

## Run the registration-operator container

The registration-operator is designed to run within a Kubernetes cluster. Running it standalone requires Kubernetes API
access and proper configuration.

To display version information:

```bash
docker run --rm dhi.io/registration-operator:<tag> --version
```

To display help information:

```bash
docker run --rm dhi.io/registration-operator:<tag> --help
```

## Deploy in Kubernetes

The recommended way to deploy registration-operator is using the OCM Helm chart or the `clusteradm` CLI.

For detailed deployment instructions, configuration options, and integration guides, refer to the official documentation
at https://open-cluster-management.io/

## Non-hardened images vs Docker Hardened Images

| Feature         | Non-hardened (quay.io/open-cluster-management/registration-operator) | Docker Hardened (dhi/registration-operator) |
| --------------- | -------------------------------------------------------------------- | ------------------------------------------- |
| Base image      | UBI 9 minimal                                                        | Debian 13 hardened base                     |
| User            | UID 10001                                                            | Nonroot user (UID 65532)                    |
| Entrypoint      | No entrypoint configured                                             | `/usr/local/bin/registration-operator`      |
| Binary location | `/registration-operator`                                             | `/usr/local/bin/registration-operator`      |
| Shell/utilities | Minimal                                                              | Not included (minimal attack surface)       |
| CVE compliance  | Standard patching                                                    | Near-zero CVEs with proactive remediation   |
| Provenance      | Not signed                                                           | Signed with complete SBOM/VEX               |

Docker Hardened Images prioritize security through minimalism. Runtime images don't contain a shell or package manager
to reduce attack surface. For debugging, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to
attach to containers with ephemeral debugging tools.

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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. Note: this image uses FIPS lenient mode (fips140=on) because the upstream
  openshift/library-go dependency uses MD5 for resource caching and SHA-1 for certificate generation. These are
  non-security uses that cannot be patched without forking the dependency.

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
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | The upstream image does not configure an entrypoint and places the binary at `/registration-operator`. The Docker Hardened image runs `/usr/local/bin/registration-operator` directly. If you override `command` or `args` in Docker or Kubernetes, update those paths and invocation patterns accordingly.                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

## Troubleshooting migration

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

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

The upstream `quay.io/open-cluster-management/registration-operator` image does not configure an entrypoint and places
the binary at `/registration-operator`. The Docker Hardened image runs `/usr/local/bin/registration-operator` directly.
If your existing Dockerfile, Compose file, or Kubernetes manifests override `command` or `args`, inspect and update
those settings to match the Docker Hardened image layout.
