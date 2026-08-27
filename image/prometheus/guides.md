## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a Prometheus instance

```
$ docker run -p 9090:9090 dhi.io/prometheus:<tag>
```

This will start Prometheus with the default configuration, exposing the web interface on http://localhost:9090.

## Common use cases

### Using a custom configuration file

Prometheus uses a YAML configuration file to define scrape targets, rules, and other settings. You can provide your own
configuration by mounting it as a volume:

```console
$ docker run -p 9090:9090 \
  -v /path/to/your/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  dhi.io/prometheus:<tag>
```

The following is a basic `prometheus.yml` configuration example:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Example: scraping a web application
  - job_name: 'my-app'
    static_configs:
      - targets: ['app:8080']
    metrics_path: /metrics
    scrape_interval: 5s

  # Example: scraping multiple instances
  - job_name: 'web-servers'
    static_configs:
      - targets:
        - 'web1:9100'
        - 'web2:9100'
        - 'web3:9100'
```

For more details, see the
[Prometheus configuration documentation](https://prometheus.io/docs/prometheus/latest/configuration/configuration/).

### Data persistence

To persist Prometheus data between container restarts, mount a volume to the data directory:

```console
$ docker run -p 9090:9090 \
  -v /path/to/your/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  -v prometheus-data:/var/prometheus \
  dhi.io/prometheus:<tag>
```

### Docker Compose setup

The following is a sample Docker Compose setup that includes Prometheus and Grafana for monitoring and visualization:

```yaml
services:
  prometheus:
    image: dhi.io/prometheus:<tag>
    container_name: prometheus
    ports:
      - 9090:9090
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prom_data:/var/prometheus
  grafana:
    image: dhi.io/grafana:<tag>
    container_name: grafana
    ports:
      - 3000:3000
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=grafana
    volumes:
      - ./grafana.yml:/etc/grafana/provisioning/datasources/prometheus.yml
volumes:
  prom_data:
```

For this example setup, create a `prometheus.yml` configuration file:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Add your application targets here
  - job_name: 'my-app'
    static_configs:
      - targets: ['my-app:8080']
    metrics_path: /metrics
    scrape_interval: 30s
```

Also, create a `grafana.yml` file to automatically configure Prometheus as a data source:

```yaml
apiVersion: 1

datasources:
- name: Prometheus
  type: prometheus
  url: http://prometheus:9090
  isDefault: true
  access: proxy
  editable: true
```

Start the stack with:

```console
$ docker-compose up -d
```

You can then access the Prometheus web interface at http://localhost:9090 and Grafana at http://localhost:3000.

### Use Prometheus in Kubernetes

To use the Prometheus hardened image in Kubernetes, [set up authentication](https://docs.docker.com/dhi/how-to/k8s/) and
update your Kubernetes deployment. For example, in your `prometheus.yaml` file, replace the image reference in the
container spec. In the following example, replace `<tag>` the desired tag.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: <kubernetes-namespace>
spec:
  template:
    spec:
      containers:
        - name: prometheus
          image: dhi.io/prometheus:<tag>
          ports:
          - containerPort: 9090
      imagePullSecrets:
        - name: <your-registry-secret>
```

Then apply the manifest to your Kubernetes cluster.

```console
$ kubectl apply -n <kubernetes-namespace> -f prometheus.yaml
```

For examples of how to configure Prometheus itself, see the [Prometheus documentation](https://prometheus.io/docs/).

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Prometheus             | Docker Hardened Prometheus                                 |
| --------------- | ----------------------------------- | ---------------------------------------------------------- |
| Base image      | Debian-based BusyBox container      | Debian hardened base                                       |
| Security        | Standard image with basic utilities | Hardened build with security patches and security metadata |
| Shell access    | BusyBox shell available             | No shell                                                   |
| Package manager | No package manager                  | No package manager                                         |
| User            | Runs as `nobody` (UID 65534)        | Runs as `nonroot` user (UID 65532)                         |
| Data directory  | `/prometheus`                       | `/var/prometheus`                                          |
| Build process   | Pre-compiled binaries               | Built from source                                          |
| Attack surface  | 400+ BusyBox utilities              | Only `prometheus`, `promtool`, and CA certificates         |
| Debugging       | BusyBox shell and utilities         | Use Docker Debug or image mount for troubleshooting        |

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

Docker Hardened Images come in different variants depending on their intended use. The Prometheus image has only runtime
variants. Runtime variants are designed to run your application in production. These images are intended to be used
either directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

## Migrate to a Docker Hardened Image

Switching to the hardened Prometheus image does not require any special changes. You can use it as a drop-in replacement
for the standard Prometheus (`prom/prometheus`) image in your existing Docker deployments and configurations. Note that
the data directory path differs from the standard image (`/var/prometheus` instead of `/prometheus`), so update your
volume mounts accordingly.

### Migration steps

1. Update your image reference. Replace the image reference in your Docker run command or Compose file:

   - From: `prom/prometheus:<tag>`
   - To: `dhi.io/prometheus:<tag>`

1. Update volume mount paths.

   Change the data directory mount from `/prometheus` to `/var/prometheus`:

   - From: `-v prometheus-data:/prometheus`
   - To: `-v prometheus-data:/var/prometheus`

1. All your existing environment variables, port mappings, and network settings remain the same.

### General migration considerations

While the specific configuration requires minimal changes, be aware of these general differences in Docker Hardened
Images:

| Item             | Migration note                                                                                                                                                                                                                                                                                                               |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Shell access     | No shell in runtime variants. Use multi-stage builds or customization.                                                                                                                                                                                                                                                       |
| Package manager  | No package manager in runtime variants. Use multi-stage builds or customization.                                                                                                                                                                                                                                             |
| User permissions | Runs as nonroot user (UID 65532) instead of nobody (UID 65534)                                                                                                                                                                                                                                                               |
| Debugging        | Use Docker Debug or image mount instead of traditional shell debugging                                                                                                                                                                                                                                                       |
| Ports            | Runtime hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |

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
