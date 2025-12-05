## How to use this image

### Run a Grafana container

Run the following command. Replace `<your-namespace>` with your organization's namespace and `<tag>` with the image
variant you want to run.

```console
$ docker run -p 3000:3000 <your-namespace>/dhi-grafana:<tag>
```

You can then access Grafana at `http://localhost:3000`. The default login is `admin` for both the username and password.

## Common Grafana use cases

### Persist Grafana data

By default, Grafana stores dashboards, users, and settings in `/var/lib/grafana`. Mount a volume to keep your data
across container restarts:

```console
$ docker run -p 3000:3000 -v grafana-storage:/var/lib/grafana <your-namespace>/dhi-grafana:<tag>
```

### Configure Grafana with environment variables

You can configure Grafana without editing config files by overriding settings using environment variables:

```console
$ docker run -d -p 3000:3000 \
  -e GF_SECURITY_ADMIN_USER=admin \
  -e GF_SECURITY_ADMIN_PASSWORD=strongpassword \
  <your-namespace>/dhi-grafana:<tag>
```

The environment variables use the following format: `GF_<SECTION NAME>_<KEY>`.

Where `<SECTION NAME>` is the text within the square brackets in the configuration file. All letters must be uppercase,
periods (.) and dashes (-) must replaced by underscores (\_).

For more details about configuring Grafana, see the
[Grafana configuration documentation](https://grafana.com/docs/grafana/latest/administration/configuration/).

### Use a custom configuration file

If you have a custom `grafana.ini` file, mount it into the container:

```console
docker run -d -p 3000:3000 \
  -v ./grafana.ini:/etc/grafana/grafana.ini \
  <your-namespace>/dhi-grafana:<tag>
```

### Run Grafana with Prometheus

Grafana is commonly paired with Prometheus for metrics visualization. You can run both containers together using Docker
Compose:

```yaml
services:
  prometheus:
    image: <your-namespace>/dhi-prometheus:<tag>
    ports:
      - "9090:9090"

  grafana:
    image: <your-namespace>/dhi-grafana:<tag>
    ports:
      - "3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana

volumes:
  grafana-storage:
```

Once both containers are running, you can add Prometheus as a data source in Grafana by navigating to the Grafana UI at
`http://localhost:3000`.

### Provision dashboards and data sources

You can mount provisioning files into `/etc/grafana/provisioning/` to automatically configure dashboards and data
sources at startup:

```console
$ docker run -d -p 3000:3000 \
  -v ./provisioning:/etc/grafana/provisioning \
  <your-namespace>/dhi-grafana:<tag>
```

# Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature            | Grafana non-hardened image            | Grafana Docker Hardened Image (DHI)                 |
| ------------------ | ------------------------------------- | --------------------------------------------------- |
| Base image         | Alpine and Ubuntu base images         | Hardened Debian base                                |
| User context       | Runs as `grafana` (uid 472, gid 0)    | Runs as `grafana` user (uid/gid 65532)              |
| Shell access       | Full shell available                  | No shell or shell utilities in runtime images       |
| Package management | Package manager included              | No package manager in runtime images                |
| Attack surface     | Larger due to additional utilities    | Minimal, only essential components                  |
| Security posture   | Standard security metadata            | Ships with SBOM and VEX metadata                    |
| Port binding       | Can bind to privileged ports (< 1024) | Cannot bind to privileged ports due to nonroot user |
| Debugging          | Traditional shell debugging           | Use Docker Debug or image mount for troubleshooting |

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

```
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=<your-namespace>/dhi-busybox,destination=/dbg,ro \
  <your-namespace>/<image-name>:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. The Grafana image has only the
runtime variants. Runtime variants are designed to run your application in production. These images are intended to be
used either directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

## Migrate to a Docker Hardened Image

Switching to the hardened Grafana image does not require any special changes. You can use it as a drop-in replacement
for the standard Grafana image in your existing workflows and configurations. Note that the entry point for the hardened
image may differ from the standard image, so ensure that your commands and arguments are compatible.

### Migration steps

1. Update your image reference. Replace the image reference in your Docker run command or Compose file:
   - From: `grafana/grafana:<tag>`
   - To: `<your-namespace>/dhi-grafana:<tag>`
1. All your existing environment variables, volume mounts, and network settings remain the same.

### General migration considerations

While the specific configuration requires no changes, be aware of these general differences in Docker Hardened Images:

| Item            | Migration note                                                         |
| --------------- | ---------------------------------------------------------------------- |
| Base images     | Based on hardened Debian, not Alpine or Ubuntu                         |
| Shell access    | No shell in runtime variants, use Docker Debug for troubleshooting     |
| Package manager | No package manager in runtime variants                                 |
| Debugging       | Use Docker Debug or image mount instead of traditional shell debugging |

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
