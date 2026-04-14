## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What’s included in this etcd image

This Docker Hardened etcd image includes a distributed key-value store and management tools in a single,
security-hardened package:

- `etcd`: A distributed, reliable key-value store that provides a consistent way to store and retrieve configuration
  data. It powers critical systems like Kubernetes by maintaining cluster state, offering features such as leader
  election, service discovery, and fault tolerance across nodes (even master ones).
- `etcdctl`: (Dev only) The official command-line client for etcd. It provides tools to manage cluster membership, check
  health, and inspect endpoints, as well as perform key-value operations like get, put, delete, and transactions. With
  support for watching changes, managing leases, and creating or restoring snapshots, etcdctl is essential for
  administering etcd clusters and interacting with the data they store.
- `etcdutl`: (Dev only) Provides administrative and diagnostic operations for etcd clusters. It is primarily intended
  for operators to inspect, manage, and recover etcd data outside of a running cluster.

## Start an etcd image

Run the following command and replace `<tag>` with the image variant you want to run

```bash
docker run \
  -p 2379:2379 \
  -p 2380:2380 \
  --name etcd dhi.io/etcd:<tag> \
  /usr/local/bin/etcd \
  --name node1
```

## Common etcd use cases

### Single-node development instance

Start a simple etcd instance for local development and testing.

```bash
docker run -d \
  --name etcd-standalone \
  -p 2379:2379 \
  -p 2380:2380 \
  dhi.io/etcd:<tag> \
  /usr/local/bin/etcd \
  --name node1 \
  --listen-client-urls http://0.0.0.0:2379 \
  --advertise-client-urls http://localhost:2379 \
  --listen-peer-urls http://0.0.0.0:2380 \
  --initial-advertise-peer-urls http://localhost:2380
```

### Multi-node cluster with Docker Compose

Deploy an etcd cluster with multiple nodes for high availability. (Not intended for production as gRPC and http server
run on a single port)

```yaml
x-common-etcd: &etcd-svc
  image: dhi.io/etcd:<tag>
  entrypoint: ["/usr/local/bin/etcd"]
  command:
    - --data-dir=/etcd-data
    - --listen-client-urls=http://0.0.0.0:2379
    - --listen-peer-urls=http://0.0.0.0:2380
    - --initial-cluster=etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380
    - --initial-cluster-token=etcd-cluster
    - --initial-cluster-state=new
    - --log-level=warn
  restart: unless-stopped
  networks: [etcd-net]

services:
  etcd1:
    <<: *etcd-svc
    hostname: etcd1
    container_name: etcd1
    environment:
      ETCD_NAME: etcd1
      ETCD_INITIAL_ADVERTISE_PEER_URLS: http://etcd1:2380
      ETCD_ADVERTISE_CLIENT_URLS: http://etcd1:2379
    ports: ["2379:2379"]  # expose one client port to host

  etcd2:
    <<: *etcd-svc
    hostname: etcd2
    container_name: etcd2
    environment:
      ETCD_NAME: etcd2
      ETCD_INITIAL_ADVERTISE_PEER_URLS: http://etcd2:2380
      ETCD_ADVERTISE_CLIENT_URLS: http://etcd2:2379

  etcd3:
    <<: *etcd-svc
    hostname: etcd3
    container_name: etcd3
    environment:
      ETCD_NAME: etcd3
      ETCD_INITIAL_ADVERTISE_PEER_URLS: http://etcd3:2380
      ETCD_ADVERTISE_CLIENT_URLS: http://etcd3:2379

networks:
  etcd-net: {}
```

### Using etcdctl for cluster management

Connect to your etcd cluster and perform administrative operations.

Check cluster health:

```bash
docker run --rm -it --network host \
  dhi.io/etcd:<tag>-dev \
  etcdctl --endpoints=localhost:2379 endpoint health
```

Put and get key-value pairs:

```bash
docker run --rm -it --network host \
  dhi.io/etcd:<tag>-dev \
  etcdctl --endpoints=localhost:2379 put mykey "Hello etcd"

docker run --rm -it --network host \
  dhi.io/etcd:<tag>-dev \
  etcdctl --endpoints=localhost:2379 get mykey
```

Create a snapshot for backup:

```bash
docker run --rm -it -v $(pwd):/backup --network host \
  dhi.io/etcd:<tag>-dev \
  etcdctl --endpoints=localhost:2379 snapshot save /backup/snapshot.db
```

### Persistent storage for production

Configure etcd with persistent volumes to maintain data across container restarts.

```bash
docker run -d \
  --name etcd-persistent \
  -p 2379:2379 \
  -p 2380:2380 \
  -v etcd-data:/etcd-data \
  dhi.io/etcd:<tag> \
  /usr/local/bin/etcd \
  --name node1 \
  --data-dir=/etcd-data \
  --listen-client-urls http://0.0.0.0:2379 \
  --advertise-client-urls http://localhost:2379
```

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature         | Docker Official etcd                | Docker Hardened etcd                                |
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

```bash
docker debug dhi.io/etcd:<tag>
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-etcd \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/etcd:<tag> /dbg/bin/sh
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

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                       |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                       |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                      |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                          |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                              |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. etcd default ports 2379 and 2380 work without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                     |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                     |

The following steps outline the general migration process.

1. **Find hardened images for your app.** A hardened image may have several variants. Inspect the image tags and find
   the image variant that meets your needs.
1. **Update the base image in your Dockerfile.** Update the base image in your application's Dockerfile to the hardened
   image you found in the previous step. For framework images, this is typically going to be an image tagged as dev
   because it has the tools needed to install packages and dependencies.
1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.** To ensure that your final image is as
   minimal as possible, you should use a multi-stage build. All stages in your Dockerfile should use a hardened image.
   While intermediary stages will typically use images tagged as dev, your final runtime stage should use a non-dev
   image variant.
1. **Install additional packages** Docker Hardened Images contain minimal packages in order to reduce the potential
   attack surface. You may need to install additional packages in your Dockerfile. Inspect the image variants to
   identify which packages are already installed. Only images tagged as dev typically have package managers. You should
   use a multi-stage Dockerfile to install the packages. Install the packages in the build stage that uses a dev image.
   Then, if needed, copy any necessary artifacts to the runtime stage that uses a non-dev image. For Alpine-based
   images, you can use apk to install packages. For Debian-based images, you can use apt-get to install packages.

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
