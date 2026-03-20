## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What’s included in this Tailscale image

This Docker Hardened Tailscale image includes the complete Tailscale networking toolkit in a single, security-hardened
package:

- `tailscale`: Tailscale CLI for managing connections and configuration
- `tailscaled`: Tailscale daemon that handles the VPN connection
- `containerboot`: Container entrypoint for seamless container integration

### Configuration and environment variables

The Docker Hardened Tailscale image supports all environment variables from the upstream Tailscale image. Common
configuration options include:

- `TS_AUTHKEY`: Authentication key for automatic connection
- `TS_ROUTES`: Routes to advertise to the Tailscale network
- `TS_DEST_IP`: Destination IP for traffic forwarding
- `TS_EXTRA_ARGS`: Additional arguments to pass to tailscaled
- `TS_STATE_DIR`: Directory for storing Tailscale state
- `TS_ACCEPT_DNS`: Whether to accept DNS configuration from the network
- `TS_USERSPACE`: Enable userspace networking instead of kernel networking (default: true)

For a complete list of environment variables and configuration options, refer to the
[official Tailscale Docker documentation](https://tailscale.com/kb/1282/docker).

## Connect to Tailscale using a container

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run -d \
  --name=tailscaled \
  -v /var/lib:/var/lib \
  -v /dev/net/tun:/dev/net/tun \
  --network=host \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  dhi.io/tailscale:<tag>
```

## Common Tailscale use cases

### Running Tailscale as a standalone container

Run Tailscale as a standalone container node on your network. This example uses an auth key for automatic
authentication.

```bash
docker run -d \
  --name=tailscaled \
  -v /var/lib/tailscale:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -e TS_AUTHKEY=tskey-auth-YOUR-AUTH-KEY \
  -e TS_STATE_DIR=/var/lib/tailscale \
  dhi.io/tailscale:<tag>
```

### Sidecar container with Docker Compose

Use Tailscale as a sidecar to provide VPN connectivity to other services. This example shows nginx accessible through
your Tailscale network using an OAuth client secret.

```yaml
version: "3.7"
services:
  tailscale-nginx:
    image: dhi.io/tailscale:<tag>
    hostname: tailscale-nginx
    environment:
      - TS_AUTHKEY=tskey-client-YOUR-OAUTH-SECRET
      - TS_EXTRA_ARGS=--advertise-tags=tag:container
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_USERSPACE=false
    volumes:
      - ${PWD}/tailscale-nginx/state:/var/lib/tailscale
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - net_admin
    restart: unless-stopped
  nginx:
    image: nginx
    depends_on:
      - tailscale-nginx
    network_mode: service:tailscale-nginx
```

### Subnet router

Advertise subnet routes to make non-Tailscale resources accessible to your Tailscale network.

```bash
docker run -d \
  --name=tailscale-subnet-router \
  -v /var/lib/tailscale:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -e TS_AUTHKEY=tskey-auth-YOUR-AUTH-KEY \
  -e TS_ROUTES=192.168.0.0/24,10.0.0.0/8 \
  -e TS_STATE_DIR=/var/lib/tailscale \
  dhi.io/tailscale:<tag>
```

### Exit node

Configure the container as a Tailscale exit node to route internet traffic through your Tailscale network.

```bash
docker run -d \
  --name=tailscale-exit-node \
  -v /var/lib/tailscale:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -e TS_AUTHKEY=tskey-auth-YOUR-AUTH-KEY \
  -e TS_EXTRA_ARGS=--advertise-exit-node \
  -e TS_STATE_DIR=/var/lib/tailscale \
  dhi.io/tailscale:<tag>
```

For additional use cases and detailed configuration options, refer to the
[official Tailscale Docker documentation](https://tailscale.com/kb/1282/docker).

## Upstream image vs. Docker Hardened Images

### Key differences

| Feature               | Upstream Tailscale (`tailscale/tailscale`) | Docker Hardened Tailscale                              |
| --------------------- | ------------------------------------------ | ------------------------------------------------------ |
| Security              | Standard base with common utilities        | Minimal, hardened base with security patches           |
| Attack surface        | Larger due to additional utilities         | Minimal, only essential components                     |
| Debugging             | Traditional shell debugging                | Use Docker Debug or Image Mount for troubleshooting    |
| Environment variables | All `TS_*` variables supported             | All `TS_*` variables supported (identical to upstream) |
| Functionality         | Full Tailscale capabilities                | Full Tailscale capabilities                            |

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
docker debug tailscaled
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:tailscaled \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/tailscale:<tag> /dbg/bin/sh
```

## Image variants

The Tailscale Docker Hardened Image provides standard runtime variants optimized for production use. These images are:

- Designed to run your application in production
- Run as the nonroot user for enhanced security
- Do not include a shell or package manager to minimize attack surface
- Contain only the minimal set of libraries needed to run Tailscale

All Tailscale functionality is available in these production-ready variants.

## Migrate to a Docker Hardened Image

The Docker Hardened Tailscale image maintains full compatibility with the upstream `tailscale/tailscale` image
configuration. All environment variables and configuration options documented in the
[official Tailscale Docker documentation](https://tailscale.com/kb/1282/docker) work identically.

### Migration steps

1. **Update your image reference.**

   Replace the image reference in your Docker run command or Compose file:

   - From: `tailscale/tailscale:<any-tag>` (e.g., `latest`, `v1.58.2`, `unstable`)
   - To: `dhi.io/tailscale:<tag>`

1. **No configuration changes needed.**

   All your existing environment variables, volume mounts, and network settings remain the same.

**Before (upstream image):**

```bash
docker run -d \
  --name=tailscaled \
  -v /var/lib/tailscale:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -e TS_AUTHKEY=tskey-auth-YOUR-AUTH-KEY \
  -e TS_STATE_DIR=/var/lib/tailscale \
  tailscale/tailscale:latest
```

**After (Docker Hardened Image):**

```bash
docker run -d \
  --name=tailscaled \
  -v /var/lib/tailscale:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -e TS_AUTHKEY=tskey-auth-YOUR-AUTH-KEY \
  -e TS_STATE_DIR=/var/lib/tailscale \
  dhi.io/tailscale:<tag>
```

### General migration considerations

While the Tailscale-specific configuration requires no changes, be aware of these general differences in Docker Hardened
Images:

| Item            | Migration note                                                         |
| --------------- | ---------------------------------------------------------------------- |
| Shell access    | No shell in runtime variants, use Docker Debug for troubleshooting     |
| Package manager | No package manager in runtime variants                                 |
| Debugging       | Use Docker Debug or Image Mount instead of traditional shell debugging |

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.
