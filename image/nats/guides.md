## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this NATS Hardened image

This image contains `nats-server`, which can be run using `docker run` or on Kubernetes via the upstream Helm chart.

## Start a NATS instance

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run -d --name nats dhi.io/nats:<tag>
```

## Common NATS use cases

### Creating a NATS cluster

First, run a server with the ports exposed on the 'nats' docker network:

```bash
docker network create nats
docker run --name nats --network nats --rm -p 4222:4222 -p 8222:8222 dhi.io/nats:<tag> --http_port 8222 --cluster_name NATS --cluster nats://0.0.0.0:6222
```

Next, start additional servers pointing them to the seed server to cause them to form a cluster:

```bash
docker run --name nats-1 --network nats --rm dhi.io/nats:<tag> --cluster_name NATS --cluster nats://0.0.0.0:6222 --routes=nats://ruser:T0pS3cr3t@nats:6222
docker run --name nats-2 --network nats --rm dhi.io/nats:<tag> --cluster_name NATS --cluster nats://0.0.0.0:6222 --routes=nats://ruser:T0pS3cr3t@nats:6222
```

To verify the routes are connected, you can make a request to the monitoring endpoint on /routez and confirm that there
are now 2 routes:

```bash
curl http://127.0.0.1:8222/routez
```

### Creating a NATS Cluster with Docker Compose

Below is a simple example that uses a network named 'nats' to create a full mesh cluster.

```yaml
#nats-cluster.yaml
version: "3.5"
services:
  nats:
    image: dhi.io/nats:<tag>
    ports:
      - "8222:8222"
    command: "--cluster_name NATS --cluster nats://0.0.0.0:6222 --http_port 8222 "
    networks: ["nats"]
  nats-1:
    image: dhi.io/nats:<tag>
    command: "--cluster_name NATS --cluster nats://0.0.0.0:6222 --routes=nats://ruser:T0pS3cr3t@nats:6222"
    networks: ["nats"]
    depends_on: ["nats"]
  nats-2:
    image: dhi.io/nats:<tag>
    command: "--cluster_name NATS --cluster nats://0.0.0.0:6222 --routes=nats://ruser:T0pS3cr3t@nats:6222"
    networks: ["nats"]
    depends_on: ["nats"]

networks:
  nats:
    name: nats
```

Now we use Docker Compose to create the cluster that will be using the 'nats' network:

```bash
docker-compose -f nats-cluster.yaml up
```

### Testing the Clusters

Now, the following should work: make a subscription on one of the nodes and publish it from another node. You should be
able to receive the message without problems.

```bash
docker run --network nats --rm -it natsio/nats-box
```

Inside the nats box container:

```bash
nats sub -s nats://nats:4222 hello &
nats pub -s "nats://nats-1:4222" hello first
nats pub -s "nats://nats-2:4222" hello second
```

Stopping the seed node, which received the subscription, should trigger an automatic failover to the other nodes:

```bash
docker-compose -f nats-cluster.yaml stop nats
```

Publishing again will continue to work after the reconnection:

```bash
nats pub -s "nats://nats-1:4222" hello again
nats pub -s "nats://nats-2:4222" hello again
```

### Install NATS using Helm

You can install NATS using the official helm chart and replace the image. Replace `<your-registry-secret>` with your
[Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>` with the desired image tag.

```bash
helm repo add nats https://nats-io.github.io/k8s/helm/charts/

helm upgrade --install nats nats/nats \
  --set "global.image.pullSecretNames[0]=<your-registry-secret>" \
  --set container.image.registry=dhi.io \
  --set container.image.repository=nats \
  --set container.image.tag=<tag>

```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened NATS                   | Docker Hardened NATS                                |
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

### Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug nats:<tag>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/nats:<tag> /dbg/bin/sh
```

### Image variants

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

- FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
  validated under FIPS 140, a U.S. government standard for secure cryptographic operations. For example, usage of MD5
  fails in FIPS variants.

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
