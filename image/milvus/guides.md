## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/milvus:<tag>`
- Mirrored image: `<your-namespace>/dhi-milvus:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this milvus image

[Milvus](https://milvus.io) is a high-performance, cloud-native vector database built for large-scale approximate
nearest neighbor (ANN) search, commonly used to power retrieval-augmented generation (RAG), semantic search, and
recommendation systems.

The image ships a single `milvus` server binary that runs any Milvus role from one entrypoint — for example,
`milvus run standalone` for a self-contained instance, or `milvus run querynode`, `milvus run datanode`, and similar
roles when deploying a distributed cluster. Matching upstream, the image sets `ENTRYPOINT ["/usr/bin/tini", "--"]` with
no default `CMD`, so you always supply the role you want `milvus` to run.

## Start a milvus image

The `milvus` CLI has no `--version` flag; running it without arguments prints the available commands and roles, and the
server version is printed in the startup banner of `milvus run`:

```bash
$ docker run --rm dhi.io/milvus:<tag> milvus
```

`standalone` is the only role that requires no external dependencies: it bundles an embedded etcd, local object storage,
and an embedded message queue in a single process, and is the fastest way to get a working instance. The embedded etcd
reads its configuration from the file referenced by `ETCD_CONFIG_PATH`, which is not shipped in the image (upstream's
standalone recipe generates and mounts it the same way), so create and mount it:

```bash
$ cat > embedEtcd.yaml <<'EOF'
listen-client-urls: http://127.0.0.1:2379
advertise-client-urls: http://127.0.0.1:2379
quota-backend-bytes: 4294967296
auto-compaction-mode: revision
auto-compaction-retention: '1000'
EOF

$ docker run -d --name milvus-standalone \
  -e ETCD_USE_EMBED=true \
  -e ETCD_DATA_DIR=/var/lib/milvus/etcd \
  -e ETCD_CONFIG_PATH=/milvus/configs/embedEtcd.yaml \
  -e COMMON_STORAGETYPE=local \
  -e DEPLOY_MODE=STANDALONE \
  -v "$(pwd)/embedEtcd.yaml:/milvus/configs/embedEtcd.yaml:ro" \
  -p 127.0.0.1:19530:19530 \
  -p 127.0.0.1:9091:9091 \
  dhi.io/milvus:<tag> \
  milvus run standalone
```

Milvus ships with authentication disabled (`common.security.authorizationEnabled` is `false`), so the gRPC API on port
`19530` and the metrics/health endpoint on port `9091` accept any caller. The examples publish both ports on the
loopback interface only; publish them on other interfaces once you have enabled authentication and TLS through
`user.yaml` (see [Custom configuration](#custom-configuration) and the upstream
[authentication](https://milvus.io/docs/authenticate.md) and [TLS](https://milvus.io/docs/tls.md) guides).

Milvus is ready once the gRPC API accepts connections and the health endpoint reports healthy. The runtime image has no
shell and no `curl`, so check the health endpoint from the host, or from a sidecar sharing the container's network
namespace:

```bash
$ docker run --rm --network container:milvus-standalone dhi.io/busybox:1 wget -qO- http://localhost:9091/healthz
```

## Common milvus use cases

### Standalone with persistent storage

The command above keeps no state across container restarts. To persist data, mount a host directory over
`/var/lib/milvus` — the directory Milvus uses for its embedded etcd data, local object storage, and rocksmq. Because
this image runs as the nonroot user `65532` (unlike the upstream image, which runs as root), the host directory must be
owned by, or writable by, that user before you start the container:

```bash
$ mkdir -p volumes/milvus
$ sudo chown 65532:65532 volumes/milvus
```

The embedded etcd also needs a config file at the path referenced by `ETCD_CONFIG_PATH`:

```bash
$ cat > embedEtcd.yaml <<'EOF'
listen-client-urls: http://127.0.0.1:2379
advertise-client-urls: http://127.0.0.1:2379
quota-backend-bytes: 4294967296
auto-compaction-mode: revision
auto-compaction-retention: '1000'
EOF

$ docker run -d --name milvus-standalone \
  -e ETCD_USE_EMBED=true \
  -e ETCD_DATA_DIR=/var/lib/milvus/etcd \
  -e ETCD_CONFIG_PATH=/milvus/configs/embedEtcd.yaml \
  -e COMMON_STORAGETYPE=local \
  -e DEPLOY_MODE=STANDALONE \
  -v "$(pwd)/volumes/milvus:/var/lib/milvus" \
  -v "$(pwd)/embedEtcd.yaml:/milvus/configs/embedEtcd.yaml:ro" \
  -p 127.0.0.1:19530:19530 \
  -p 127.0.0.1:9091:9091 \
  dhi.io/milvus:<tag> \
  milvus run standalone
```

### Custom configuration

Milvus resolves its configuration directory as `$CWD/configs` unless the `MILVUSCONF` environment variable overrides it.
Because the image's `WORKDIR` is `/milvus` and `/milvus/configs` is a symlink to the packaged configuration directory,
mount a `user.yaml` override (Milvus merges it over the packaged `milvus.yaml`) at `/milvus/configs/user.yaml`. Keep the
standalone environment from the sections above — the `user.yaml` mount is additive:

```bash
$ docker run -d --name milvus-standalone \
  -e ETCD_USE_EMBED=true \
  -e ETCD_DATA_DIR=/var/lib/milvus/etcd \
  -e ETCD_CONFIG_PATH=/milvus/configs/embedEtcd.yaml \
  -e COMMON_STORAGETYPE=local \
  -e DEPLOY_MODE=STANDALONE \
  -v "$(pwd)/embedEtcd.yaml:/milvus/configs/embedEtcd.yaml:ro" \
  -v "$(pwd)/user.yaml:/milvus/configs/user.yaml:ro" \
  -p 127.0.0.1:19530:19530 \
  -p 127.0.0.1:9091:9091 \
  dhi.io/milvus:<tag> \
  milvus run standalone
```

### FIPS-validated cryptography

The `fips` and `fips-dev` variants ship a Milvus binary linked with the Go Cryptographic Module (`GOFIPS140`), which
runs in FIPS 140-3 mode by default, and configure the system OpenSSL used by the C++ core with the image's
FIPS-validated provider (`openssl-provider-fips`). The startup log reports `Milvus FIPS in OpenSSL: enabled` once the
provider is active. The line before it, `Milvus FIPS in Go: BoringCrypto false`, is expected: the Go side's FIPS mode
comes from the Go Cryptographic Module, not from upstream's BoringCrypto build. No extra configuration is needed beyond
selecting a `-fips` tag. Two Rust components compiled into the C++ core carry their own TLS and hashing crates, which
are outside both validated modules: the full-text index binding (rustls with ring, both lines) and, in Milvus 3.0, the
storage v2 bridge that reads and writes Lance and Vortex files in object storage (rustls with aws-lc-rs, native-tls over
the system OpenSSL, and RustCrypto digests). Object storage traffic that goes through that bridge negotiates TLS with
rustls rather than with the validated OpenSSL provider.

### Cluster deployments

The `standalone` role above is self-contained and suitable for development, testing, and many production workloads.
Distributed cluster deployments additionally require an external etcd cluster, S3-compatible object storage (for example
MinIO), and a Pulsar or Kafka message queue, typically coordinated with the Milvus Operator or the official Helm chart:

- [Install Milvus in cluster mode](https://milvus.io/docs/install_cluster-milvusoperator.md)
- [Milvus Helm charts](https://github.com/zilliztech/milvus-helm)

When following the upstream Operator manifests or Helm chart, override the image reference to `dhi.io/milvus:<tag>` in
place of the default `milvusdb/milvus` image.

## Non-hardened images vs. Docker Hardened Images

Unlike the upstream `milvusdb/milvus` image, which runs as root, this image's runtime and `fips` variants run as the
nonroot user `65532`. If you bind-mount a host directory over `/var/lib/milvus`, make sure it's owned by or writable by
`65532:65532` — the in-image directory already is, but host paths are not until you `chown` them (see
[Standalone with persistent storage](#standalone-with-persistent-storage)). For the same reason, embedded-etcd
deployments must set `ETCD_DATA_DIR` to a writable location such as `/var/lib/milvus/etcd`: the upstream default
(`default.etcd`, relative to the root-owned working directory `/milvus`) is not writable by the nonroot user.

The runtime image also has no shell and no `curl`, so upstream's own healthcheck
(`curl -f http://localhost:9091/healthz`) doesn't work unmodified; see [Start a milvus image](#start-a-milvus-image) for
a working alternative.

Upstream's sample TLS key pairs under `configs/cert` are not shipped. When you enable TLS (`common.security.tlsMode`),
mount your own certificates and point `tls.serverPemPath`, `tls.serverKeyPath` and `tls.caPemPath` at them in
`user.yaml`.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

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
