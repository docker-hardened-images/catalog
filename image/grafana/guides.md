## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Run a Grafana container

```console
$ docker run -p 3000:3000 dhi.io/grafana:<tag>
```

You can then access Grafana at `http://localhost:3000`. The default login is `admin` for both the username and password.

## Common Grafana use cases

### Persist Grafana data

By default, Grafana stores dashboards, users, and settings in `/var/lib/grafana`. Mount a volume to keep your data
across container restarts:

```console
$ docker run -p 3000:3000 -v grafana-storage:/var/lib/grafana dhi.io/grafana:<tag>
```

### Configure Grafana with environment variables

You can configure Grafana without editing config files by overriding settings using environment variables:

```console
$ docker run -d -p 3000:3000 \
  -e GF_SECURITY_ADMIN_USER=admin \
  -e GF_SECURITY_ADMIN_PASSWORD=strongpassword \
  dhi.io/grafana:<tag>
```

The environment variables use the following format: `GF_<SECTION NAME>_<KEY>`.

Where `<SECTION NAME>` is the text within the square brackets in the configuration file. All letters must be uppercase,
periods (.) and dashes (-) must replaced by underscores (\_).

> **Note:** The following environment variables from the upstream Docker image do not work in DHI images because they
> are processed by the upstream shell script entrypoint, which is not present in hardened images:
>
> - `GF_PATHS_CONFIG`, `GF_PATHS_DATA`, `GF_PATHS_HOME`, `GF_PATHS_LOGS`, `GF_PATHS_PLUGINS`, `GF_PATHS_PROVISIONING`
>   - See [Override default paths](#override-default-paths) for how to accomplish this manually.
> - `GF_AWS_PROFILES` (and related `GF_AWS_*_ACCESS_KEY_ID`, `GF_AWS_*_SECRET_ACCESS_KEY`, `GF_AWS_*_REGION`)
>   - See [Configure AWS credentials](#configure-aws-credentials) for how to accomplish this manually.
> - `GF_*__FILE` variables (Docker secrets expansion, e.g., `GF_SECURITY_ADMIN_PASSWORD__FILE`)
>   - See [Use Docker secrets](#use-docker-secrets) for how to accomplish this manually.
> - `GF_INSTALL_PLUGINS` (automatic plugin installation)
>   - See [Install Grafana plugins](#install-grafana-plugins) for how to accomplish this manually.

For more details about configuring Grafana, see the
[Grafana configuration documentation](https://grafana.com/docs/grafana/latest/administration/configuration/).

### Use a custom configuration file

If you have a custom `grafana.ini` file, mount it into the container:

```console
docker run -d -p 3000:3000 \
  -v ./grafana.ini:/etc/grafana/grafana.ini \
  dhi.io/grafana:<tag>
```

The DHI image automatically loads configuration from `/etc/grafana/grafana.ini`, just like the upstream image.

### Override default paths

The DHI Grafana image uses the following default paths:

| Path                        | Purpose                |
| --------------------------- | ---------------------- |
| `/etc/grafana/grafana.ini`  | Configuration file     |
| `/var/lib/grafana`          | Data directory         |
| `/var/log/grafana`          | Log directory          |
| `/var/lib/grafana/plugins`  | Plugins directory      |
| `/etc/grafana/provisioning` | Provisioning directory |

If you need to use custom paths, override the entrypoint command and modify only the paths you need to change:

```console
$ docker run -p 3000:3000 dhi.io/grafana:<tag> \
  grafana server \
    --homepath=/usr/share/grafana \
    --config=/custom/path/grafana.ini \
    --packaging=docker \
    cfg:default.log.mode=console \
    cfg:default.paths.data=/custom/data \
    cfg:default.paths.logs=/var/log/grafana \
    cfg:default.paths.plugins=/var/lib/grafana/plugins \
    cfg:default.paths.provisioning=/etc/grafana/provisioning
```

In the above example, `--config` and `cfg:default.paths.data` are changed to custom values. Always include the full
entrypoint command when overriding paths.

### Run Grafana with Prometheus

Grafana is commonly paired with Prometheus for metrics visualization. You can run both containers together using Docker
Compose:

```yaml
services:
  prometheus:
    image: dhi.io/prometheus:<tag>
    ports:
      - "9090:9090"

  grafana:
    image: dhi.io/grafana:<tag>
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
  dhi.io/grafana:<tag>
```

### Install Grafana plugins

The upstream Docker image supports `GF_INSTALL_PLUGINS` to install plugins at startup. Since DHI images don't include a
shell, use a multi-stage Dockerfile with the dev variant to pre-install plugins:

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: Install plugins using dev variant
FROM dhi.io/grafana:<tag>-dev AS plugin-build

# Install plugins using grafana cli (--homepath required to find config defaults)
RUN grafana cli --homepath /usr/share/grafana --pluginsDir /var/lib/grafana/plugins plugins install grafana-clock-panel && \
    grafana cli --homepath /usr/share/grafana --pluginsDir /var/lib/grafana/plugins plugins install grafana-piechart-panel

# Stage 2: Runtime image with plugins
FROM dhi.io/grafana:<tag>

# Copy installed plugins from build stage
COPY --from=plugin-build /var/lib/grafana/plugins /var/lib/grafana/plugins
```

To install a plugin from a custom URL:

```dockerfile
RUN grafana cli --homepath /usr/share/grafana --pluginsDir /var/lib/grafana/plugins \
    --pluginUrl https://example.com/my-plugin.zip \
    plugins install my-custom-plugin
```

**Alternative: Use provisioning** (no custom image required)

Grafana 10.3+ supports
[plugin provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/#plugins) via
`GF_PLUGINS_PREINSTALL` or configuration files. This allows plugins to be installed at startup without a shell:

```console
$ docker run -d -p 3000:3000 \
  -e GF_PLUGINS_PREINSTALL=grafana-clock-panel,grafana-piechart-panel \
  dhi.io/grafana:<tag>
```

Or via provisioning file mounted at `/etc/grafana/provisioning/plugins/plugins.yaml`:

```yaml
apiVersion: 1
apps:
  - type: grafana-clock-panel
  - type: grafana-piechart-panel
```

### Configure AWS credentials

The upstream Docker image supports `GF_AWS_PROFILES` to automatically create AWS credentials from environment variables.
For DHI images, mount your credentials file directly:

```console
$ docker run -d -p 3000:3000 \
  -v ~/.aws/credentials:/usr/share/grafana/.aws/credentials:ro \
  dhi.io/grafana:<tag>
```

Or use IAM roles for service accounts (IRSA) in Kubernetes, which is the recommended approach for production
environments.

For Docker Compose:

```yaml
services:
  grafana:
    image: dhi.io/grafana:<tag>
    ports:
      - "3000:3000"
    volumes:
      - ./aws-credentials:/usr/share/grafana/.aws/credentials:ro
    environment:
      - AWS_SDK_LOAD_CONFIG=true
```

### Use Docker secrets

The upstream Docker image supports `GF_*__FILE` variables to read secrets from files (Docker secrets). For DHI images,
use one of these approaches:

**Option 1: Mount secrets and use Grafana's native file support**

Some Grafana settings support reading values from files directly. Configure these in `grafana.ini`:

```ini
[database]
password = $__file{/run/secrets/db_password}

[security]
admin_password = $__file{/run/secrets/admin_password}
```

Then mount the secrets:

```console
$ docker run -d -p 3000:3000 \
  -v ./secrets/db_password:/run/secrets/db_password:ro \
  -v ./secrets/admin_password:/run/secrets/admin_password:ro \
  -v ./grafana.ini:/etc/grafana/grafana.ini:ro \
  dhi.io/grafana:<tag>
```

**Option 2: Use Kubernetes secrets**

In Kubernetes, mount secrets as environment variables or files:

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: grafana
      image: dhi.io/grafana:<tag>
      env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secrets
              key: admin-password
```

**Option 3: Init container for complex secret handling**

For cases requiring shell processing (like the `GF_*__FILE` pattern), use an init container:

```yaml
apiVersion: v1
kind: Pod
spec:
  initContainers:
    - name: secrets-init
      image: dhi.io/busybox:<tag>
      command:
        - sh
        - -c
        - |
          cat /secrets/admin-password > /shared/GF_SECURITY_ADMIN_PASSWORD
      volumeMounts:
        - name: secrets
          mountPath: /secrets
        - name: shared
          mountPath: /shared
  containers:
    - name: grafana
      image: dhi.io/grafana:<tag>
      env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secrets
              key: admin-password
```

## Non-hardened images vs. Docker Hardened Images

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
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/<image-name>:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- **Runtime variants** (default) are designed to run your application in production. These images are intended to be
  used either directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- **Dev variants** (`-dev` suffix) are intended for use in the first stage of a multi-stage Dockerfile. These images
  typically:

  - Run as the root user
  - Include a shell and package manager
  - Include the `grafana cli` tool for plugin installation
  - Are used to build custom images with pre-installed plugins

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

Switching to the hardened Grafana image does not require any special changes. You can use it as a drop-in replacement
for the standard Grafana image in your existing workflows and configurations. Note that the entry point for the hardened
image may differ from the standard image, so ensure that your commands and arguments are compatible.

### Migration steps

1. Update your image reference. Replace the image reference in your Docker run command or Compose file:
   - From: `grafana/grafana:<tag>`
   - To: `dhi.io/grafana:<tag>`
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

The DHI Grafana image runs `grafana server` directly with explicit path arguments, rather than using a shell script like
the upstream image. This means:

- Standard usage works identically to upstream
- `GF_<SECTION>_<KEY>` environment variables work normally
- Some upstream environment variables have no effect (see the note in
  [Configure Grafana with environment variables](#configure-grafana-with-environment-variables))
