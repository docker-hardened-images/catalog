## Prerequisites

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository** > **Mirror to
repository**, and then follow the on-screen instructions.

Refer to the [upstream's documentation](https://docs.haproxy.org/)⁠ on the subject of configuring HAProxy for your
needs.

## Start a HAProxy image

Run a basic HAProxy container and output the version with the following command. Replace <your-namespace> with your
organization's namespace and <tag> with the image variant you want to run.

```bash
docker run <your-namespace>/dhi-haproxy:<tag> -v
```

Run a HAProxy container with a mounted configuration directory:

```bash
docker run -v /path/to/haproxy:/usr/local/etc/haproxy:ro <your-namespace>/dhi-haproxy:<tag> -f /usr/local/etc/haproxy
```

Using Docker Compose:

```yaml
services:
  haproxy:
    image: <your-namespace>/dhi-haproxy:<tag>
    volumes:
      - ./haproxy:/usr/local/etc/haproxy:ro
    ports:
      - "8080:8080"
      - "8443:8443"
    command: ["-f", "/usr/local/etc/haproxy"]
```

## Common HAProxy use cases

#### Basic HTTP load balancer

Create a simple load balancer configuration in `haproxy.cfg`:

```haproxy
global
    maxconn 256

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend http-in
    bind *:8080
    default_backend servers

backend servers
    server server1 192.168.1.10:80 check
    server server2 192.168.1.11:80 check
```

Mount and run with:

```bash
docker run -v $(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  -p 8080:8080 <your-namespace>/dhi-haproxy:<tag> \
  -f /usr/local/etc/haproxy
```

#### Load balancer with SSL termination

Configure SSL termination in `haproxy.cfg`:

```haproxy
global
    maxconn 256

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend https-in
    bind *:8443 ssl crt /usr/local/etc/haproxy/certs/server.pem
    default_backend servers

backend servers
    server server1 192.168.1.10:80 check
    server server2 192.168.1.11:80 check
```

Mount certificates and configuration:

```bash
docker run -v $(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  -v $(pwd)/certs:/usr/local/etc/haproxy/certs:ro \
  -p 8443:8443 <your-namespace>/dhi-haproxy:<tag> \
  -f /usr/local/etc/haproxy
```

#### TCP load balancer for databases

Configure TCP mode for database load balancing:

```haproxy
global
    maxconn 256

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend database-in
    bind *:5432
    default_backend db-servers

backend db-servers
    balance roundrobin
    server db1 192.168.1.20:5432 check
    server db2 192.168.1.21:5432 check
```

## Docker Official Images vs. Docker Hardened Images

Key differences for HAProxy:

| Feature         | Docker Official HAProxy             | Docker Hardened HAProxy                             |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

## Image variants

Docker Hardened Images come in different variants depending on their intended use:

- **Runtime variants** are designed to run HAProxy in production. These images:

  - Run as the nonroot user
  - Do not include a shell or package manager
  - Contain only the minimal set of libraries needed to run HAProxy

- **Build-time variants** typically include `dev` in the variant name and are intended for building custom HAProxy
  configurations or plugins. These images:

  - Run as the root user
  - Include a shell and package manager
  - Can be used to compile HAProxy modules or validate configurations

## Migrate to a Docker Hardened Image

### HAProxy-specific migration requirements

When migrating from Docker Official Images to Docker Hardened Images for HAProxy, consider the following:

#### Port binding restrictions

The nonroot user cannot bind to privileged ports (below 1024). Update your HAProxy configuration to use ports 1025 and
above inside the container:

```haproxy
# Change from:
bind *:80
bind *:443

# To:
bind *:8080
bind *:8443
```

Use Docker's port mapping to expose these on privileged ports on the host:

```bash
docker run -p 80:8080 -p 443:8443 <your-namespace>/dhi-haproxy:<tag>
```

#### Configuration file permissions

Ensure configuration files are readable by the nonroot user. Mount configurations with appropriate permissions:

```bash
chmod 644 haproxy.cfg
docker run -v $(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  <your-namespace>/dhi-haproxy:<tag>
```

#### Entry point differences

Verify the entry point behavior matches your expectations. Use `docker inspect` to check:

```bash
docker inspect <your-namespace>/dhi-haproxy:<tag>
```

#### Stats socket location

If using the stats socket, ensure it's writable by the nonroot user. Consider using a mounted volume:

```bash
docker run -v haproxy-socket:/var/run/haproxy \
  <your-namespace>/dhi-haproxy:<tag>
```

## Troubleshoot migration

### General Debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use Docker Debug to attach to these containers. Docker
Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that
only exists during the debugging session.

```bash
docker debug <your-namespace>/dhi-haproxy:<tag>
```

### HAProxy won't start - permission denied on port binding

Symptom: HAProxy fails to start with a "permission denied" error when binding to ports below 1024.

Solution: Update your HAProxy configuration to use unprivileged ports (1025 and above) and use Docker port mapping to
expose privileged ports on the host.

### Configuration file not found or not readable

Symptom: HAProxy reports that it cannot read the configuration file.

Solution: Verify that:

- The configuration file exists in the mounted location
- The file has appropriate read permissions (644 or similar)
- The mount path in the Docker command matches the path specified in the HAProxy command

### Stats socket permission denied

Symptom: HAProxy cannot create or write to the stats socket.

Solution: Create a named volume or bind mount with appropriate permissions for the nonroot user to write the socket
file, typically in `/var/run/haproxy`.

### Cannot debug running container

Symptom: Unable to exec into the container because there's no shell.

Solution: Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach an ephemeral debugging
session to the container with a shell and debugging tools.

## Other

### Configuration validation

To validate your HAProxy configuration before deploying, use a dev variant image:

```bash
docker run --rm -v $(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  dhi-haproxy:<tag>-dev \
  <your-namespace>/haproxy:<tag> -c -f /usr/local/etc/haproxy/haproxy.cfg
```

### Additional documentation

For detailed HAProxy configuration and tuning guidance, refer to the
[official HAProxy documentation](https://docs.haproxy.org/).
