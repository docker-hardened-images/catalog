## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this NATS Hardened image

This image contains `nats`, `nats-top`, `nsc`, and `nk`, a set of command line utilities to interact with NATS.

## Start a NATS box instance

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run --rm -it dhi/nats-box:<tag>-dev
```

## Common NATS Box use cases

### Testing Clusters

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

Now, the following should work: make a subscription on one of the nodes and publish it from another node. You should be
able to receive the message without problems.

```bash
docker run --network nats --rm -it dhi.io/nats-box:<tag> nats sub -s nats://nats:4222 hello
docker run --network nats --rm dhi.io/nats-box:<tag> nats pub -s "nats://nats-1:4222" hello first
docker run --network nats --rm dhi.io/nats-box:<tag> nats pub -s "nats://nats-2:4222" hello second
```

Alertnatively, the compat and dev variants provide a shell where you can run the above commands from a single container:

```bash
docker run --network nats --rm -it dhi.io/nats-box:<tag>-dev
```

Then, from inside the nats box container:

```bash
nats sub -s nats://nats:4222 hello &
nats pub -s "nats://nats-1:4222" hello first
nats pub -s "nats://nats-2:4222" hello second
```

### Check the state of a NATS server

NATS top can be used to check the state of a running NATS server. For example:

```bash
docker run --rm -it dhi.io/nats-box:<tag> nats-top -s demo.nats.io -ms 8222
```

And your terminal should start displaying the state of NATS' demo server:

```console
NATS server version 2.12.3 (uptime: 35d15h17m57s)
Server: us-south-nats-demo
  ID:   NBHHFJYFFS2IZDESGVUU457CW7LAUDSPPXIGDRPGHBKGVYUICSYJZEQJ
  Load: CPU:  4.0%  Memory: 234.6M  Slow Consumers: 1202
  In:   Msgs: 107.3M  Bytes: 169.2G  Msgs/Sec: 11.0  Bytes/Sec: 348
  Out:  Msgs: 108.6M  Bytes: 106.0G  Msgs/Sec: 1.0  Bytes/Sec: 74

Connections Polled: 87
  HOST                                             CID    NAME                                                                 SUBS    PENDING     MSGS_TO     MSGS_FROM   BYTES_TO    BYTES_FROM  LANG     VERSION  UPTIME   LAST_ACTIVITY
  195.201.27.167:49080                             1972                                                                        1       0           0           0           0           0           nats.js  3.1.0    35d15h17m57s  2025-12-17 18:21:44.54897959
  ...
```

### Create NATS account configuration

NATS account configurations are built using the nsc tool.

```bash
docker run --rm -it -v $(pwd):/nsc dhi.io/nats-box:<tag> nsc init -d /nsc
```

And you should see some output similar to this:

```console
[ OK ] created operator optimistic_poincare
[ OK ] created system_account: name:SYS id:ACUOSERIJ7X4AWLBP4W4NODLE4RVKBCYCSPHWII5JV66R24K6OMK3XAH
[ OK ] created system account user: name:sys id:UC5EWNG5KXDS3YZLZXVOZY2FGUVXODFLCTQ7SRTOTAJK7NDCN44FF5V6
[ OK ] system account user creds file stored in `/nsc/nkeys/creds/optimistic_poincare/SYS/sys.creds`
[ OK ] created account optimistic_poincare
[ OK ] created user "optimistic_poincare"
[ OK ] project jwt files created in `/nsc`
[ OK ] user creds file stored in `/nsc/nkeys/creds/optimistic_poincare/optimistic_poincare/optimistic_poincare.creds`
> to run a local server using this configuration, enter:
>   nsc generate config --mem-resolver --config-file <path/server.conf>
> then start a nats-server using the generated config:
>   nats-server -c <path/server.conf>
all jobs succeeded
```

### Generate NKeys

nk is a command line tool that generates nkeys.

NKeys are a highly secure public-key signature system based on Ed25519. With NKeys the server can verify identity
without ever storing secrets on the server. The authentication system works by requiring a connecting client to provide
its public key and digitally sign a challenge with its private key. The server generates a random challenge with every
connection request, making it immune to playback attacks. The generated signature is validated a public key, thus
proving the identity of the client. If the public key validation succeeds, authentication succeeds.

```bash
docker run --rm -it dhi.io/nats-box:<tag> nk -gen user -pubout
```

And keys should be printed to stdout:

```console
SUANNIZCTANZEW77UEJRG27W2FKBVE5F5R75OQPY5CIKIQFKKU6B6ICSC4
UD6RJ4LKRG7LSTKFG7CDJZH4UMAWULYTJF43XPOA2WENA6SQAHUBZK5C
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened NATS Box               | Docker Hardened NATS Bo                             |
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
docker debug dhi.io/nats-box:<tag>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/nats-box:<tag> /dbg/bin/sh
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
