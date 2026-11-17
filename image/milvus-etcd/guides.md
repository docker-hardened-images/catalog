## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this milvus-etcd image

[milvus-etcd](https://github.com/milvus-io/bitnami-docker-etcd) is the etcd distribution maintained by the
[Milvus](https://milvus.io) project as the metadata store for Milvus vector database deployments. The image contains the
official [etcd](https://etcd.io) server together with the `etcdctl` and `etcdutl` tools, plus the Bitnami-compatible
startup scripts under `/opt/bitnami/scripts` that render the etcd configuration from `ETCD_*` environment variables.
This is the image the [milvus-helm](https://github.com/zilliztech/milvus-helm) chart deploys as its `etcd` dependency.
The packaged etcd server follows the newest upstream etcd 3.5.x patch release so security fixes land without waiting for
a new tag of the packaging repository, so it can be ahead of the etcd version embedded in the `milvusdb/etcd` tags.

Because the container's entrypoint is a script, this image differs from most hardened runtime images: it includes `bash`
and the minimal userland the scripts need (including `yq`). It still runs as a non-root user and contains no package
manager.

### Run the milvus-etcd container

The startup scripts refuse to start etcd without authentication unless you explicitly allow it, matching upstream
behavior. To start a single development node (the client port is bound to loopback because the instance accepts
unauthenticated requests):

```bash
docker run --rm -p 127.0.0.1:2379:2379 \
  -e ALLOW_NONE_AUTHENTICATION=yes \
  dhi.io/milvus-etcd:<tag>
```

To print the release version of the packaged etcd binary:

```bash
docker run --rm dhi.io/milvus-etcd:<tag> etcd --version
```

To secure the instance, set a root password instead of allowing unauthenticated access:

```bash
docker run --rm -p 2379:2379 \
  -e ETCD_ROOT_PASSWORD=<password> \
  dhi.io/milvus-etcd:<tag>
```

### Configure milvus-etcd

Configuration follows the upstream milvusdb/etcd conventions: any
[etcd configuration flag](https://etcd.io/docs/latest/op-guide/configuration/) can be set through its `ETCD_*`
environment variable, and every supported variable can also be loaded from a file by appending `_FILE` to its name (for
example `ETCD_ROOT_PASSWORD_FILE=/run/secrets/etcd-root-password`). If a configuration file exists at
`/opt/bitnami/etcd/conf/etcd.yaml`, etcd starts with `--config-file` and the scripts update it with the rendered values.

Persistent state lives in `/bitnami/etcd/data`. Mount a volume there to keep the keyspace across container restarts
(loopback-bound for the same reason as above):

```bash
docker run --rm -p 127.0.0.1:2379:2379 \
  -e ALLOW_NONE_AUTHENTICATION=yes \
  -v etcd-data:/bitnami/etcd \
  dhi.io/milvus-etcd:<tag>
```

The scripts also support the upstream cluster lifecycle features used by the milvus-helm chart, including
`ETCD_ON_K8S=yes` for Kubernetes member discovery, `ETCD_START_FROM_SNAPSHOT` / `ETCD_INIT_SNAPSHOT_FILENAME` to
bootstrap from a snapshot in `/init-snapshot`, and `/opt/bitnami/scripts/etcd/snapshot.sh` to write periodic snapshots
to `/snapshots`.

### Use with the milvus-helm chart

The milvus-helm chart consumes this image through its `etcd` dependency. Point the chart at the hardened image by
overriding the image values:

```yaml
etcd:
  image:
    registry: dhi.io
    repository: milvus-etcd
    tag: <tag>
```

The image keeps the upstream directory layout (`/opt/bitnami/etcd`, `/bitnami/etcd/data`), lifecycle scripts, and
default user UID (1001), so probes, snapshots, and persistence settings from the chart work unchanged.

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature         | Non-hardened milvusdb/etcd                       | Docker Hardened milvus-etcd                                                             |
| --------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------- |
| etcd version    | etcd embedded in the packaging tag (e.g. 3.5.30) | Newest upstream etcd 3.5.x patch release (can be ahead of the `milvusdb/etcd` tags)     |
| Shell           | Full Ubuntu userland                             | `bash` and a minimal userland are present (required by the entrypoint scripts)          |
| Package manager | apt available                                    | No package manager in runtime variants                                                  |
| User            | 1001, root group; state dirs group-writable      | uid 1001 owns the state dirs (0770); on Kubernetes use `fsGroup` for volume ownership   |
| State layout    | Created by the entrypoint on first start         | `/opt/bitnami/etcd/{conf,certs,tmp}`, `/bitnami/etcd`, and `/snapshots` are pre-created |
| Attack surface  | Larger due to full distro base                   | Minimal: only etcd, the scripts, and the userland the scripts need                      |

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  > **milvus-etcd is an exception to the no-shell rule:** its entrypoint is a bash script, so the runtime variants ship
  > `bash` and a minimal userland. They still run as a non-root user and contain no package manager.

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. milvus-etcd is an exception: its runtime variants ship `bash` because the entrypoint is a bash script. Use dev images in build stages for anything beyond what the packaged scripts need.                                                           |

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

Most hardened images intended for runtime don't contain a shell nor any tools for debugging; milvus-etcd is an exception
and ships `bash`, so `docker exec` into a running container works for basic inspection. The recommended method for
deeper debugging of applications built with Docker Hardened Images is to use
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

By default, image variants intended for runtime don't contain a shell. milvus-etcd is an exception: its runtime variants
ship `bash` because the entrypoint scripts require it. For other images, use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage, and use Docker Debug to debug containers with no
shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
