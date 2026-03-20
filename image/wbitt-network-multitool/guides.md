## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this wbitt-network-multitool image

This Docker Hardened wbitt-network-multitool image includes:

- **nginx** - Minimal web server for serving test content and providing HTTP/HTTPS endpoints
- **curl** - HTTP client for testing endpoints
- **wget** - Non-interactive network downloader
- **dig** - DNS lookup utility (from bind-tools)
- **nslookup** - Legacy DNS lookup utility
- **ping** - ICMP echo utility for connectivity tests
- **traceroute** - Network path tracing tool
- **mtr** - Combines ping and traceroute for diagnostics
- **tcpdump** - Packet capture tool
- **netstat** - Network connections and listening ports (net-tools)
- **ip** - iproute2 utilities for interface and route management
- **jq** - JSON processor for API responses

The `-extra` variant includes additional tools for advanced networking, database connectivity, and security testing:

- **apache2-utils** - Apache HTTP server benchmarking tools (ab, htpasswd)
- **ethtool** - Ethernet device configuration and diagnostics
- **git** - Version control system
- **iperf3** - Network performance measurement and tuning tool
- **lftp** - Sophisticated FTP/HTTP client
- **mysql-client** - MySQL database client for connectivity testing
- **netcat-openbsd** - TCP/IP swiss army knife for port scanning and data transfer
- **net-snmp-tools** - SNMP tools for network management
- **nmap** - Network exploration and security auditing tool
- **nmap-scripts** - Nmap scripting engine scripts for advanced scanning
- **postgresql-client** - PostgreSQL database client for connectivity testing
- **samba-client** - SMB/CIFS client tools for Windows file sharing
- **socat** - Multipurpose relay tool for bidirectional data transfer
- **tshark** - Network protocol analyzer (Wireshark CLI)

## Start a wbitt-network-multitool image

### Basic usage

Run the following command to start a wbitt-network-multitool container with the default nginx web server:

```bash
$ docker run -d --name wbitt-network-multitool -p 80:80 -p 443:443 \
  dhi.io/wbitt-network-multitool:<tag>
```

This starts the container with nginx listening on ports 80 (HTTP) and 443 (HTTPS).

### Interactive shell access

To get an interactive shell and use the networking tools:

```bash
$ docker run --rm -it dhi.io/wbitt-network-multitool:<tag>-dev /bin/sh
```

Note: Use the `-dev` variant for interactive shell access, as runtime variants don't include a shell.

### With Docker Compose

```yaml
version: '3.8'
services:
  network-multitool:
    image: dhi.io/wbitt-network-multitool:<tag>
    container_name: wbitt-network-multitool
    ports:
      - "80:80"
      - "443:443"
    environment:
      - HTTP_PORT=80
      - HTTPS_PORT=443
```

### Environment variables

| Variable     | Description                     | Default | Required |
| ------------ | ------------------------------- | ------- | -------- |
| `HTTP_PORT`  | Override the default HTTP port  | `80`    | No       |
| `HTTPS_PORT` | Override the default HTTPS port | `443`   | No       |

Example with custom ports:

```bash
$ docker run -d --name wbitt-network-multitool \
  -e HTTP_PORT=8080 \
  -e HTTPS_PORT=8443 \
  -p 8080:8080 \
  -p 8443:8443 \
  dhi.io/wbitt-network-multitool:<tag>
```

## Common wbitt-network-multitool use cases

### Network troubleshooting in Kubernetes

Deploy as a pod for network troubleshooting:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: wbitt-network-multitool
spec:
  containers:
  - name: wbitt-network-multitool
    image: dhi.io/wbitt-network-multitool:<tag>
    ports:
    - containerPort: 80
    - containerPort: 443
```

Or run directly with kubectl:

```bash
$ kubectl run wbitt-network-multitool --image=dhi.io/wbitt-network-multitool:<tag>
```

### DNS resolution testing

Test DNS resolution from within a running container:

```bash
$ docker exec -it wbitt-network-multitool dig google.com
$ docker exec -it wbitt-network-multitool nslookup google.com
```

### Network connectivity testing

Test network connectivity and HTTP endpoints:

```bash
$ docker exec -it wbitt-network-multitool ping -c 4 8.8.8.8
$ docker exec -it wbitt-network-multitool curl -I https://www.google.com
```

### Network path tracing

Trace the network path to a destination:

```bash
$ docker exec -it wbitt-network-multitool mtr -c 10 google.com
```

Note: `mtr` works without elevated privileges. For `traceroute`, see the "Tools requiring privileged mode" section
below.

### Packet capture

Note: `tcpdump` requires privileged mode. See the "Tools requiring privileged mode" section below for usage.

### Port scanning and checking

Check open ports and network connections:

```bash
$ docker exec -it wbitt-network-multitool netstat -tulpn
```

### Custom web content

Mount your own HTML content to replace the default index page:

```bash
$ docker run -d --name wbitt-network-multitool \
  -v /path/to/html:/usr/share/nginx/html:ro \
  -p 80:80 \
  dhi.io/wbitt-network-multitool:<tag>
```

### Using the extra variant for advanced testing

For database connectivity testing, security scanning, or advanced networking:

```bash
$ docker run --rm -it dhi.io/wbitt-network-multitool:<tag>-extra-dev /bin/sh
```

Inside the container, you can use tools like:

```bash
# Database connectivity
$ mysql -h database-host -u user -p
$ psql -h database-host -U user

# Network performance testing
$ iperf3 -c server-host

# Security scanning
$ nmap -sV target-host

# Protocol analysis
$ tshark -i eth0
```

### Tools requiring privileged mode

Some network diagnostic tools require elevated privileges to access raw network sockets. These tools need `--privileged`
mode when using the `-dev` variant (which runs as root).

**Traceroute:**

```bash
$ docker run --rm --privileged \
  dhi.io/wbitt-network-multitool:<tag>-dev /bin/sh -c "traceroute google.com"
```

**Packet capture (tcpdump):**

```bash
$ docker run --rm --privileged \
  dhi.io/wbitt-network-multitool:<tag>-dev /bin/sh -c "tcpdump -i any -c 10 icmp"
```

Or with a running container:

```bash
$ docker run -d --name wbitt-network-multitool --privileged \
  dhi.io/wbitt-network-multitool:<tag>-dev sleep 3600
$ docker exec -it wbitt-network-multitool tcpdump -i any -c 10
```

**Note:** The `-dev` variant runs as root user, which provides the necessary permissions for these diagnostic tools when
combined with `--privileged` mode.

## Notes and limitations

- Runtime variants run as non-root user (nginx, UID 65532) for enhanced security
- Dev variants run as root user to allow package installation and system modifications
- The nginx process itself runs as the nginx user (UID 65532) in all variants for security
- Self-signed SSL certificates are automatically generated at `/certs/server.crt` and `/certs/server.key`
- Access and error logs are forwarded to stdout/stderr for container log collection
- The web root is at `/usr/share/nginx/html/`
- The container includes a built-in health check that verifies nginx is responding on the HTTP port
- For interactive shell access and running commands, use the `-dev` variant
- Tools like `traceroute` and `tcpdump` require `--privileged` mode to access raw network sockets

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
