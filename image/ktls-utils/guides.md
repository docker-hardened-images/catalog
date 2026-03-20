## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a tlshd instance

Run the following command to start tlshd. Replace `<tag>` with the image variant you want to run.

```bash
docker run -d --name tlshd \
  --privileged \
  --network host \
  dhi.io/ktls-utils:<tag>
```

**Important notes:**

- The `--privileged` flag is required because tlshd needs to interact with kernel netlink sockets and manage kernel TLS
  sessions
- The `--network host` flag is typically required because tlshd operates on kernel sockets
- Mount your tlshd configuration directory to `/etc/tlshd` for custom configuration

## Common ktls-utils use cases

### Basic tlshd daemon with default configuration

Start tlshd with a minimal `/etc/tlshd/config` configuration file:

```bash
# Create a minimal config
mkdir -p /etc/tlshd
cat > /etc/tlshd/config << 'EOF'
[debug]
loglevel = 0
tls = 0
nl = 0

[authenticate]
keyrings =
EOF

# Run tlshd
docker run -d --name tlshd \
  --privileged \
  --network host \
  -v /etc/tlshd:/etc/tlshd:ro \
  dhi.io/ktls-utils:<tag>
```

## Docker Official Images vs. Docker Hardened Images

### Key differences

| Feature         | Standard Linux Package         | Docker Hardened ktls-utils                          |
| --------------- | ------------------------------ | --------------------------------------------------- |
| Security        | Standard system packages       | Minimal, hardened base with security patches        |
| Shell access    | Full shell available           | No shell in runtime variants                        |
| Package manager | apt/yum available              | No package manager in runtime variants              |
| User            | Runs as root via systemd       | Runs as nonroot user                                |
| Attack surface  | Larger due to system utilities | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging    | Use Docker Debug or Image Mount for troubleshooting |
| Configuration   | /etc/tlshd/config              | Same configuration file location                    |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Container logs via `docker logs`

For example, you can use Docker Debug:

```bash
docker debug tlshd
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:tlshd \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  dhi.io/ktls-utils:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run tlshd

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. Docker Hardened ktls-utils images include FIPS-compliant variants for environments requiring
Federal Information Processing Standards compliance.

## Migrate to a Docker Hardened Image

To migrate your tlshd deployment to a Docker Hardened Image, you must update your deployment configuration. At minimum,
you must update the container image reference to a Docker Hardened Image. This and a few other common changes are listed
in the following table of migration notes:

| Item               | Migration note                                                                                                                                                                          |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your container images with a Docker Hardened Image.                                                                                                                             |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                             |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. However, tlshd requires privileged access to kernel netlink sockets, so you must run with `--privileged` flag. |
| Configuration      | Mount your configuration directory to `/etc/tlshd`. The configuration file format is identical to the standard ktls-utils package.                                                      |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. Mount your own certificates and configure them in `/etc/tlshd/config`.                                             |
| Network mode       | tlshd typically requires `--network host` to access kernel sockets directly.                                                                                                            |
| Entry point        | Docker Hardened ktls-utils maintains the same tlshd command-line options as the standard package.                                                                                       |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.             |

The following steps outline the general migration process.

1. **Prepare your configuration.**

   Ensure you have a valid tlshd configuration file at `/etc/tlshd/config` on your host system. Review the configuration
   file reference section above for available options.

1. **Prepare certificates (if using x.509 authentication).**

   Place your certificates and private keys in a directory that you'll mount into the container. Update your
   configuration file to reference the paths where these files will be mounted.

1. **Update your container deployment.**

   Replace your existing tlshd container with the Docker Hardened Image:

   ```bash
   docker run -d --name tlshd \
     --privileged \
     --network host \
     -v /etc/tlshd:/etc/tlshd:ro \
     dhi.io/ktls-utils:<tag>
   ```

1. **Verify operation.**

   Check the container logs to ensure tlshd started successfully:

   ```bash
   docker logs tlshd
   ```

   You should see log messages indicating that tlshd is listening for netlink messages from the kernel.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

For tlshd-specific debugging:

```bash
# View logs
docker logs tlshd

# Run with debug output to stderr
docker run -d --name tlshd \
  --privileged \
  --network host \
  -v /etc/tlshd:/etc/tlshd:ro \
  dhi.io/ktls-utils:<tag> \
  tlshd --stderr
```

### Permissions

By default, image variants intended for runtime run as the nonroot user. However, tlshd requires privileged access to
kernel netlink sockets and must run with the `--privileged` flag to function correctly.

### Configuration file errors

tlshd will exit immediately if `/etc/tlshd/config` does not exist or is malformed. Ensure your configuration file:

- Is mounted to the correct path (`/etc/tlshd/config`)
- Has correct syntax (INI-style format)
- References valid paths for certificates and keys
- Is readable by the container user

### Kernel requirements

tlshd requires Linux kernel 6.5 or later with the following CONFIG options enabled:

- `CONFIG_TLS`
- `CONFIG_KEYS`
- `CONFIG_KEYS_REQUEST_CACHE`

Verify your kernel supports net/handshake:

```bash
# Check kernel version
uname -r

# Check if /proc/net/handshake exists
ls /proc/net/handshake 2>/dev/null || echo "Kernel handshake support not available"
```

### Certificate and keyring issues

If tlshd cannot access certificates or keyrings:

- Verify certificate files are mounted and readable
- Check file paths in `/etc/tlshd/config` match mounted locations
- Ensure certificate files are in PEM format
- Verify private key permissions are appropriate

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened ktls-utils maintains the same entry point and command-line options as the standard ktls-utils package.
Use `docker inspect` to inspect entry points for Docker Hardened Images if necessary.
