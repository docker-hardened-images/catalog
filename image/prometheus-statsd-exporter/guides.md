## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/prometheus-statsd-exporter:<tag>`
- Mirrored image: `<your-namespace>/dhi-prometheus-statsd-exporter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This guide provides practical examples for using the Prometheus StatsD Exporter Hardened Image for metrics collection
and transformation.

## What's included in this StatsD Exporter image

This Docker Hardened StatsD Exporter image provides the Prometheus StatsD Exporter in three variants:

## Start a StatsD Exporter container

```bash
docker run -d \
  --name statsd-exporter \
  -p 9102:9102 \
  -p 9125:9125/udp \
  dhi.io/prometheus-statsd-exporter:<tag>
```

This starts the exporter to listen for StatsD metrics on UDP port 9125 and expose Prometheus metrics at
`http://localhost:9102/metrics`.

## Common use cases

### Run with custom configuration

To configure StatsD Exporter with custom ports and paths:

```bash
docker run -d \
  --name statsd-exporter \
  -p 8080:8080 \
  -p 8125:8125/udp \
  dhi.io/prometheus-statsd-exporter:<tag> \
  --web.listen-address=0.0.0.0:8080 \
  --web.telemetry-path=/custom-metrics \
  --statsd.listen-udp=0.0.0.0:8125
```

### Run with a mapping configuration file

To use a mapping configuration file to transform StatsD metrics into meaningful Prometheus metrics:

```bash
docker run -d \
  --name statsd-exporter \
  -p 9102:9102 \
  -p 9125:9125/udp \
  -v /path/to/statsd-mapping.yml:/etc/statsd-mapping.yml:ro \
  dhi.io/prometheus-statsd-exporter:<tag> \
  --statsd.mapping-config=/etc/statsd-mapping.yml
```

Example mapping configuration (`statsd-mapping.yml`):

```yaml
---
mappings:
  - match: test.dispatcher.*.*.*
    name: dispatcher_events
    labels:
      processor: $1
      action: $2
      outcome: $3
  - match: test.*.count
    name: ${1}_total
    labels:
      job: test-service
```

### Run with environment variables

You can also configure StatsD Exporter using environment variables:

```bash
docker run -d \
  --name statsd-exporter \
  -p 9102:9102 \
  -p 9125:9125/udp \
  -e STATSD_EXPORTER_WEB_LISTEN_ADDRESS=0.0.0.0:9102 \
  -e STATSD_EXPORTER_WEB_TELEMETRY_PATH=/metrics \
  -e STATSD_EXPORTER_STATSD_LISTEN_UDP=0.0.0.0:9125 \
  dhi.io/prometheus-statsd-exporter:<tag>
```

### Run with Docker Compose

Create a directory structure:

```console
$ mkdir -p statsd-dhi-test
$ cd statsd-dhi-test
```

Create the mapping configuration file:

```bash
cat <<EOF > statsd-mapping.yml
---
mappings:
  - match: app.requests.*.*
    name: app_requests_total
    labels:
      endpoint: \$1
      method: \$2
  - match: app.response_time.*
    name: app_response_time_seconds
    labels:
      endpoint: \$1
EOF
```

Create Docker Compose file:

```bash
cat <<EOF > docker-compose.yml
services:
  statsd-exporter:
    image: dhi.io/prometheus-statsd-exporter:<tag>
    ports:
      - "9102:9102"
      - "9125:9125/udp"
    volumes:
      - ./statsd-mapping.yml:/etc/statsd-mapping.yml:ro
    command:
      - --statsd.mapping-config=/etc/statsd-mapping.yml
      - --statsd.cache-size=2000
    restart: unless-stopped
EOF
```

Start the stack:

```console
$ docker compose up -d
```

Verify the metrics endpoint:

```console
$ curl http://localhost:9102/metrics
# HELP statsd_exporter_build_info A metric with a constant '1' value labeled by version, revision, branch, and goversion from which statsd_exporter was built.
# TYPE statsd_exporter_build_info gauge
statsd_exporter_build_info{...} 1
```

### Run with Docker Compose (Full Stack with Prometheus)

For production-like setups with Prometheus scraping the StatsD Exporter:

```bash
cat <<EOF > docker-compose.yml
services:
  statsd-exporter:
    image: dhi.io/prometheus-statsd-exporter:<tag>
    ports:
      - "9102:9102"
      - "9125:9125/udp"
    volumes:
      - ./statsd-mapping.yml:/etc/statsd-mapping.yml:ro
    command:
      - --statsd.mapping-config=/etc/statsd-mapping.yml
    restart: unless-stopped

  prometheus:
    image: dhi.io/prometheus:<tag>
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    tmpfs:
      - /prometheus:uid=65532,gid=65532
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
    depends_on:
      - statsd-exporter
EOF
```

> **Note:** The DHI Prometheus image runs as nonroot (UID 65532). Using `tmpfs` with the correct uid/gid ensures the
> container can write to the data directory. For persistent storage, create a volume with appropriate ownership.

Create Prometheus configuration:

```bash
cat <<EOF > prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'statsd-exporter'
    static_configs:
      - targets: ['statsd-exporter:9102']
EOF
```

Start the full stack:

```console
$ docker compose up -d
```

Verify all services are running:

```console
$ docker compose ps
NAME                                IMAGE                                      COMMAND                  SERVICE           CREATED         STATUS         PORTS
statsd-dhi-test-prometheus-1        dhi.io/prometheus:<tag>                      "prometheus --config…"   prometheus        6 seconds ago   Up 5 seconds   0.0.0.0:9090->9090/tcp
statsd-dhi-test-statsd-exporter-1   dhi.io/prometheus-statsd-exporter:<tag>   "/usr/local/bin/stat…"   statsd-exporter   6 seconds ago   Up 5 seconds   0.0.0.0:9102->9102/tcp, 0.0.0.0:9125->9125/udp
```

Verify Prometheus is healthy and scraping:

```console
$ curl -s http://localhost:9090/-/healthy
Prometheus Server is Healthy.

$ curl -s http://localhost:9090/api/v1/targets | grep '"health"'
"health":"up"
```

### Sending StatsD metrics

Once StatsD Exporter is running, you can send metrics from your applications using any StatsD client:

```bash
# Counter
echo "api.requests:1|c" | nc -u -w1 localhost 9125

# Gauge
echo "cpu.usage:75.5|g" | nc -u -w1 localhost 9125

# Timer
echo "api.response_time:150|ms" | nc -u -w1 localhost 9125

# Histogram
echo "request.size:1024|h" | nc -u -w1 localhost 9125

# With tags (DogStatsD format)
echo "api.requests:1|c|#endpoint:users,method:GET" | nc -u -w1 localhost 9125
```

The metrics will be converted to Prometheus format and available at the `/metrics` endpoint.

### Use StatsD Exporter in Kubernetes

To use the StatsD Exporter hardened image in Kubernetes,
[set up authentication](https://docs.docker.com/dhi/how-to/k8s/) and update your Kubernetes deployment.

```bash
cat <<EOF > statsd-exporter.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: statsd-mapping
  namespace: default
data:
  statsd-mapping.yml: |
    ---
    mappings:
      - match: app.requests.*.*
        name: app_requests_total
        labels:
          endpoint: \$1
          method: \$2
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: statsd-exporter
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: statsd-exporter
  template:
    metadata:
      labels:
        app: statsd-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9102"
    spec:
      containers:
        - name: statsd-exporter
          image: dhi.io/prometheus-statsd-exporter:<tag>
          args:
            - --statsd.mapping-config=/etc/statsd-mapping/statsd-mapping.yml
          ports:
            - containerPort: 9102
              name: metrics
            - containerPort: 9125
              protocol: UDP
              name: statsd
          volumeMounts:
            - name: statsd-mapping
              mountPath: /etc/statsd-mapping
              readOnly: true
      volumes:
        - name: statsd-mapping
          configMap:
            name: statsd-mapping
      imagePullSecrets:
        - name: <your-registry-secret>
---
apiVersion: v1
kind: Service
metadata:
  name: statsd-exporter
  namespace: default
spec:
  ports:
    - port: 9102
      targetPort: 9102
      name: metrics
    - port: 9125
      targetPort: 9125
      protocol: UDP
      name: statsd
  selector:
    app: statsd-exporter
EOF
```

Then apply the manifest to your Kubernetes cluster:

```console
$ kubectl apply -n default -f statsd-exporter.yaml
```

Verify the deployment:

```console
$ kubectl get pods -l app=statsd-exporter
NAME                               READY   STATUS    RESTARTS   AGE
statsd-exporter-7d8f9c6b4d-xyz12   1/1     Running   0          30s
```

Access the metrics endpoint:

```console
$ kubectl port-forward -n default deployment/statsd-exporter 9102:9102
```

Then visit http://localhost:9102/metrics in your browser.

For examples of how to configure StatsD Exporter itself, see the
[Prometheus StatsD Exporter documentation](https://github.com/prometheus/statsd_exporter).

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened StatsD Exporter        | Docker Hardened StatsD Exporter                            |
| --------------- | ----------------------------------- | ---------------------------------------------------------- |
| Base image      | Debian/Alpine with full utilities   | Debian hardened base                                       |
| Security        | Standard image with basic utilities | Hardened build with security patches and security metadata |
| Shell access    | Shell (`/bin/sh`) available         | No shell (runtime variants)                                |
| Package manager | Package manager available           | No package manager (runtime variants)                      |
| User            | Runs as root or specified user      | Runs as nonroot user                                       |
| Attack surface  | Full OS utilities and tools         | Only StatsD Exporter binary, no additional utilities       |
| Debugging       | Full shell and utilities            | Use Docker Debug or image mount for troubleshooting        |

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

```console
$ docker run -d --name statsd-test dhi.io/prometheus-statsd-exporter:<tag>
$ docker debug statsd-test
```

Inside the debug session:

```console
docker > cat /etc/os-release
NAME="Docker Hardened Images (Debian)"
ID=debian
VERSION_ID=13
VERSION_CODENAME=trixie
PRETTY_NAME="Docker Hardened Images/Debian GNU/Linux 13 (trixie)"
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

### Runtime variants

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (UID 65532)
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the StatsD Exporter

### Dev variants

Dev variants include `dev` in the tag name and are intended for use in the first stage of a multi-stage Dockerfile.
These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. Docker Hardened StatsD Exporter images include FIPS-compliant variants for environments
requiring Federal Information Processing Standards compliance.

#### Steps to verify FIPS:

```shell
# Compare image sizes (FIPS variants are larger due to FIPS crypto libraries)
$ docker images | grep statsd-exporter
dhi.io/prometheus-statsd-exporter   <tag>        4.96 MB
dhi.io/prometheus-statsd-exporter   <tag>-fips   16.75 MB

# Verify FIPS compliance using image labels
$ docker inspect dhi.io/prometheus-statsd-exporter:<tag>-fips \
  --format '{{index .Config.Labels "com.docker.dhi.compliance"}}'
fips
```

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

#### Runtime requirements specific to FIPS:

- FIPS mode enforces stricter cryptographic standards
- Use FIPS variants when exposing metrics over TLS with FIPS-compliant certificates
- Required for deployments in US government or regulated environments
- Only FIPS-approved cryptographic algorithms are available for TLS connections

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                                                    |
| Non-root user      | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                     |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

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

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
