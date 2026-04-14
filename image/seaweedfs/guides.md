## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a SeaweedFS instance

#### All-in-one server mode

The simplest way to run SeaweedFS is with the `server` command, which starts master, volume, and filer services in a
single container:

```bash
docker run -d --name seaweedfs \
  -p 9333:9333 \
  -p 8080:8080 \
  -p 8888:8888 \
  -v $(pwd)/data:/data \
  dhi.io/seaweedfs:<tag> server
```

This starts a complete SeaweedFS instance with:

- Master server on port 9333 (cluster coordination)
- Volume server on port 8080 (data storage)
- Filer server on port 8888 (filesystem interface)

#### Individual service modes

For production deployments, run each service separately:

**Master server:**

```bash
docker run -d --name seaweedfs-master \
  -p 9333:9333 \
  -p 19333:19333 \
  -v $(pwd)/master-data:/data \
  dhi.io/seaweedfs:<tag> master
```

**Volume server:**

```bash
docker run -d --name seaweedfs-volume \
  -p 8080:8080 \
  -p 18080:18080 \
  -v $(pwd)/volume-data:/data \
  dhi.io/seaweedfs:<tag> volume -mserver="master-host:9333"
```

**Filer server:**

```bash
docker run -d --name seaweedfs-filer \
  -p 8888:8888 \
  -p 18888:18888 \
  -v $(pwd)/filer-data:/data \
  dhi.io/seaweedfs:<tag> filer -master="master-host:9333"
```

**S3 gateway:**

```bash
docker run -d --name seaweedfs-s3 \
  -p 8333:8333 \
  -e S3_DOMAIN_NAME="s3.example.com" \
  dhi.io/seaweedfs:<tag> s3 -filer="filer-host:8888"
```

## Common SeaweedFS use cases

## Configuration

SeaweedFS is primarily configured through command-line flags passed to the service mode commands. Each service (master,
volume, filer, s3) accepts different flags.

### Common Configuration Options

**Master server:**

- `-mdir` - Directory for master data (default: `/data`)
- `-volumePreallocate` - Preallocate disk space for volumes
- `-volumeSizeLimitMB` - Default volume size limit in MB (default: `1024`)
- `-defaultReplication` - Default replication type, e.g., `000`, `001`, `010` (default: `000`)

**Volume server:**

- `-dir` - Directory for volume data (default: `/data`)
- `-max` - Maximum number of volumes (default: `0` = auto)
- `-mserver` - Comma-separated master servers (default: `localhost:9333`)
- `-port` - HTTP port (default: `8080`)

**Filer server:**

- `-master` - Comma-separated master servers (default: `localhost:9333`)
- `-port` - HTTP port (default: `8888`)
- `-defaultReplicaPlacement` - Default replication for files (default: `000`)

**S3 gateway:**

- `-filer` - Filer server address (default: `localhost:8888`)
- `-port` - S3 port (default: `8333`)
- `-domainName` - Domain name for virtual-host-style requests

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened SeaweedFS       | Docker Hardened SeaweedFS              |
| --------------- | ---------------------------- | -------------------------------------- |
| Base image      | Alpine Linux                 | Debian 13 hardened base                |
| Security        | Standard Alpine packages     | Security patches + signed metadata     |
| Shell access    | Shell available (`/bin/sh`)  | No shell                               |
| Package manager | `apk` available              | No package manager                     |
| User            | Runs as `seaweed` (UID 1000) | Runs as `seaweed` (UID 65532)          |
| Build process   | Pre-compiled binaries        | Built from source with verified commit |
| Debugging       | Shell + basic tools          | Docker Debug or Image Mount            |
| SBOM            | Not included                 | Complete SBOM included                 |
| CVE scanning    | Not guaranteed               | Published with near-zero known CVEs    |

## Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Application-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/seaweedfs:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a non-root user (UID 65532)
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- Compat variants support more seamless usage of DHI as a drop-in replacement for upstream images, particularly for
  circumstances that the ultra-minimal runtime variant may not fully support. These images typically:

  - Run as a non-root user (UID 65532)
  - Improve compatibility with upstream helm charts
  - Include optional tools that are critical for certain use-cases

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The default
ports are:

- Master: 9333 (HTTP), 19333 (gRPC)
- Volume: 8080 (HTTP), 18080 (gRPC)
- Filer: 8888 (HTTP), 18888 (gRPC)
- S3: 8333
- WebDAV: 7333

No configuration changes are needed to run SeaweedFS as a nonroot user.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
