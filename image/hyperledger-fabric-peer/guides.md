## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The Hyperledger Fabric Peer is the main runtime node that manages and provides access to the blockchain ledger. Peers
host ledgers and smart contracts (chaincode), execute chaincode logic, and endorse transactions on behalf of their
organization. Each peer maintains a local copy of the ledger and validates incoming transactions against configured
endorsement policies before committing them to the blockchain. The hardened image provides the same functionality as
upstream Hyperledger Fabric but runs with Docker Hardened Image security guarantees.

## Using Hyperledger Fabric Peer

The peer requires configuration files and cryptographic credentials to operate. Before running a peer, you need to
generate the required cryptographic material and obtain a configuration file.

### Step 1: Generate cryptographic material

Use the Docker Hardened Hyperledger Fabric Tools image to generate cryptographic credentials. First, clone the
fabric-samples repository which contains the necessary configuration files:

```bash
git clone https://github.com/hyperledger/fabric-samples.git
cd fabric-samples/test-network
```

Then pull the Hyperledger Fabric Tools hardened image:

```bash
docker pull dhi.io/hyperledger-fabric-tools:<tag>
```

Generate cryptographic material for an organization using cryptogen:

```bash
docker run --rm \
  -v $(pwd):/work \
  -w /work \
  dhi.io/hyperledger-fabric-tools:<tag> \
  cryptogen generate \
  --config=organizations/cryptogen/crypto-config-org1.yaml \
  --output=organizations
```

This creates the MSP and TLS certificates needed for the peer at:

- MSP: `organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp`
- TLS: `organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls`

### Step 2: Obtain peer configuration

The peer requires a `core.yaml` configuration file. You can use the sample configuration from the fabric-samples
repository:

```bash
ls compose/docker/peercfg/core.yaml
```

This file contains all the default settings for running a peer.

### Step 3: Run the peer

Create a directory for the peer's ledger data:

```bash
mkdir -p /tmp/peer0-data
```

Run the peer with all required configuration:

```bash
docker run --rm \
  -v $(pwd)/compose/docker/peercfg/core.yaml:/etc/hyperledger/fabric/core.yaml \
  -v $(pwd)/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp:/etc/hyperledger/fabric/msp \
  -v $(pwd)/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls:/etc/hyperledger/fabric/tls \
  -v /tmp/peer0-data:/var/hyperledger/production \
  -p 7051:7051 \
  -p 7052:7052 \
  -p 9443:9443 \
  --name peer0.org1.example.com \
  dhi.io/hyperledger-fabric-peer:<tag>
```

The peer will start and:

- Listen on port 7051 for peer-to-peer communication and client requests
- Listen on port 7052 for chaincode callbacks
- Listen on port 9443 for operations service (metrics and health checks)
- Store ledger data in `/tmp/peer0-data`

### Understanding the configuration

**Required volume mounts:**

- `core.yaml`: Main configuration file mounted at `/etc/hyperledger/fabric/core.yaml`
- MSP credentials: Organization identity at `/etc/hyperledger/fabric/msp`
- TLS credentials: Certificates for secure communication at `/etc/hyperledger/fabric/tls`
- Ledger data: Writable directory at `/var/hyperledger/production`

**Key environment variables:**

- `CORE_PEER_ID`: Unique identifier for this peer
- `CORE_PEER_LOCALMSPID`: MSP ID of the organization this peer belongs to
- `CORE_PEER_LISTENADDRESS`: Address the peer listens on (use 0.0.0.0 to accept connections from all interfaces)
- `CORE_PEER_CHAINCODEADDRESS`: Address chaincode containers connect to (must not be 0.0.0.0)
- `CORE_PEER_TLS_ENABLED`: Enable TLS for secure communication
- `FABRIC_LOGGING_SPEC`: Set log level (DEBUG, INFO, WARN, ERROR)

**Exposed ports:**

- 7051: Main peer service port
- 7052: Chaincode listen port
- 9443: Operations service (metrics, health checks)

For detailed configuration options, see the
[Hyperledger Fabric peer configuration documentation](https://hyperledger-fabric.readthedocs.io/en/latest/deploypeer/peerchecklist.html).

### Verifying the peer is working

After starting the peer, you can verify it's operational using several methods:

**Check container status:**

```bash
docker ps --filter name=peer0.org1.example.com
```

The peer should show as "Up" with the correct ports exposed.

**Check peer logs:**

```bash
docker logs peer0.org1.example.com --tail 50
```

Look for successful startup messages:

- `Started peer` - Peer started successfully
- `Deployed system chaincodes` - System chaincodes (cscc, qscc, \_lifecycle) deployed
- `Initialize gossip` - Gossip service initialized

**Test TLS connectivity:**

Verify the peer's gRPC port is accessible:

```bash
docker run --rm --network container:peer0.org1.example.com nicolaka/netshoot nc -zv 127.0.0.1 7051
```

This should return "Connection succeeded" if the peer is listening.

## Common Hyperledger Fabric Peer use cases

The https://github.com/hyperledger/fabric-samples repository includes samples that can be used to create Hyperledger
Fabric networks. The test-network directory, for example includes materials and a script, network.sh that can be used to
create a test network with docker-compose. To deploy a network using the hardened image, simply replace the image in the
docker compose file, for the test-network example located at `test-network/compose/compose-test-net.yaml`, from
`hyperledger/fabric-peer:latest` to `dhi.io/hyperledger-fabric-peer:<tag>`.

See documentation at https://hyperledger-fabric.readthedocs.io/ and https://github.com/hyperledger/fabric-samples for
further details on running Hyperledger Fabric and the provided examples.

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Hyperledger Fabric Peer | Docker Hardened Hyperledger Fabric Peer |
| --------------- | ------------------------------------ | --------------------------------------- |
| Base image      | Ubuntu-based                         | Debian hardened base                    |
| Security        | Standard utilities                   | Security patches + metadata             |
| Shell access    | Shell available                      | No shell                                |
| Package manager | `apt`                                | No package manager                      |
| User            | Runs as root                         | Runs as dedicated non-root user         |
| Build process   | Pre-compiled binaries                | Built from source with verified commit  |
| Debugging       | Shell + tools                        | Docker Debug or Image Mount             |
| SBOM            | Not included                         | SBOM included                           |

## Hardened image debugging

Docker Hardened Images for Hyperledger Fabric Peer do not include a shell or package manager to minimize the attack
surface and reduce image size. This means you cannot use `docker exec` to access a shell inside a running container.
However, Docker provides alternative debugging methods that work seamlessly with hardened images.

The recommended approach is to use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/), which attaches
an ephemeral debug container with a shell and common debugging tools to your running container. This allows you to
inspect the container's filesystem, processes, and network configuration without modifying the production image.

For Hyperledger Fabric Peer specifically, you can also debug by examining the ledger data and logs. Mount volumes to
persist these outputs and inspect them on your host system. Additionally, enable verbose logging by setting the
FABRIC_LOGGING_SPEC environment variable (for example `-e FABRIC_LOGGING_SPEC=debug`).

### Using Docker Debug

Attach a debug shell to a running Hyperledger Fabric Peer container:

```bash
docker debug <container-name>
```

This opens a shell in the debug container where you can inspect the filesystem, check running processes with `ps`, or
examine network connections with `netstat`.

### Using Docker Image Mount

Mount the container's filesystem to your host for inspection:

```bash
docker image mount dhi.io/hyperledger-fabric-peer:<tag> /mnt/inspect
ls -la /mnt/inspect/usr/local/bin/
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

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
