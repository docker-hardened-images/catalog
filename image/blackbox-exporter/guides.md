## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/blackbox-exporter:<tag>`
- Mirrored image: `<your-namespace>/dhi-blackbox-exporter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Prometheus Blackbox Exporter Hardened image

This image contains the Prometheus Blackbox Exporter, which can be run using `docker run` or on Kubernetes via custom
deployment manifests.

## Start a Blackbox Exporter instance

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run -d --name blackbox-exporter -p 9115:9115 dhi.io/blackbox-exporter:<tag>
```

The exporter will be available at `http://localhost:9115`. You can access the web UI at `http://localhost:9115` and
probe endpoints via `http://localhost:9115/probe` like for example pinging a website:

```console
curl "http://localhost:9115/probe?target=google.com&module=http_2xx"
# HELP probe_dns_lookup_time_seconds Returns the time taken for probe dns lookup in seconds
# TYPE probe_dns_lookup_time_seconds gauge
probe_dns_lookup_time_seconds 0.019044708
# HELP probe_duration_seconds Returns how long the probe took to complete in seconds
# TYPE probe_duration_seconds gauge
probe_duration_seconds 0.683054709
# HELP probe_failed_due_to_regex Indicates if probe failed due to regex
# TYPE probe_failed_due_to_regex gauge
```

## Common Blackbox Exporter use cases

### Basic HTTP probe with custom configuration

Create a custom configuration file for your probes:

```bash
cat > blackbox-config.yml << EOF
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: []
      method: GET
      no_follow_redirects: false
      fail_if_ssl: false
      fail_if_not_ssl: false
      tls_config:
        insecure_skip_verify: false

  http_post_2xx:
    prober: http
    timeout: 5s
    http:
      method: POST
      headers:
        Content-Type: application/json

  tcp_connect:
    prober: tcp
    timeout: 5s

  icmp_ping:
    prober: icmp
    timeout: 5s
EOF  
```

Run the exporter with your custom configuration:

```bash
docker run -d --name blackbox-exporter \
  -p 9115:9115 \
  -v $(pwd)/blackbox-config.yml:/etc/blackbox_exporter/config.yml:ro \
  dhi.io/blackbox-exporter:<tag> \
  --config.file=/etc/blackbox_exporter/config.yml
```

### TLS/SSL certificate monitoring

Configure a probe to monitor certificate expiration:

```bash
cat > tls-monitoring.yml << EOF
modules:
  http_2xx_with_cert_check:
    prober: http
    timeout: 10s
    http:
      method: GET
      valid_status_codes: []
      fail_if_not_ssl: true
      tls_config:
        insecure_skip_verify: false
EOF
```

Run the exporter:

```bash
docker run -d --name blackbox-exporter \
  -p 9115:9115 \
  -v $(pwd)/tls-monitoring.yml:/etc/blackbox_exporter/config.yml:ro \
  dhi.io/blackbox-exporter:<tag> \
  --config.file=/etc/blackbox_exporter/config.yml
```

Test the probe:

```bash
curl 'http://localhost:9115/probe?target=https://example.com&module=http_2xx_with_cert_check'
```

### Using Docker Compose with multiple probes

Create a complete monitoring setup with Docker Compose. The example uses the DHI Prometheus image (`dhi.io/prometheus`),
which runs as a non-root user (uid 65532). The `prometheus-init` service (using a minimal `busybox` image) ensures the
data volume is writable by that user before Prometheus starts.

```bash
cat > docker-compose.yml << EOF
version: "3.8"
services:
  blackbox-exporter:
    image: dhi.io/blackbox-exporter:<tag>
    ports:
      - "9115:9115"
    volumes:
      - ./blackbox-config.yml:/etc/blackbox_exporter/config.yml:ro
    command:
      - '--config.file=/etc/blackbox_exporter/config.yml'
      - '--log.level=info'
    cap_add:
      - NET_RAW  # Required for ICMP probes
    restart: unless-stopped

  prometheus-init:
    image: dhi.io/busybox:<tag>
    user: "0:0"
    volumes:
      - prometheus-data:/var/prometheus
    command: ["chown", "-R", "65532:65532", "/var/prometheus"]
    restart: "no"

  prometheus:
    image: dhi.io/prometheus:<tag>
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/var/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/var/prometheus'
    depends_on:
      prometheus-init:
        condition: service_completed_successfully
      blackbox-exporter:
        condition: service_started
    restart: unless-stopped

volumes:
  prometheus-data: {}
EOF
```

Create a Prometheus configuration to scrape the Blackbox Exporter:

```bash
cat > prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://example.com
          - https://prometheus.io
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  - job_name: 'blackbox_exporter'
    static_configs:
      - targets: ['blackbox-exporter:9115']
EOF
```

Start the stack:

```bash
docker-compose up -d
```

### Deploy on Kubernetes with the upstream Helm chart

You can install Prometheus Blackbox Exporter using the official community Helm chart and replace the image. Replace
`<your-registry-secret>` with your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>`
with the desired image tag.

```bash
helm install blackbox-exporter oci://ghcr.io/prometheus-community/charts/prometheus-blackbox-exporter \
  --set "imagePullSecrets[0].name=<your-registry-secret>" \
  --set image.registry=dhi.io \
  --set image.repository=blackbox-exporter \
  --set image.tag=<tag>
```

Verify the installation:

```console
kubectl get all
NAME                                                                  READY   STATUS    RESTARTS   AGE
pod/blackbox-exporter-prometheus-blackbox-exporter-6fc886469b-c8jfp   1/1     Running   0          2s

NAME                                                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/blackbox-exporter-prometheus-blackbox-exporter   ClusterIP   10.103.248.23   <none>        9115/TCP   2s
service/kubernetes                                       ClusterIP   10.96.0.1       <none>        443/TCP    14d

NAME                                                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blackbox-exporter-prometheus-blackbox-exporter   1/1     1            1           2s

NAME                                                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/blackbox-exporter-prometheus-blackbox-exporter-6fc886469b   1         1         1       2s
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Prometheus Blackbox Exporter | Docker Hardened Prometheus Blackbox Exporter        |
| --------------- | ----------------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities       | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available            | No shell in runtime variants                        |
| Package manager | apt/apk available                         | No package manager in runtime variants              |
| User            | Runs as root by default                   | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities        | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging               | Use Docker Debug or Image Mount for troubleshooting |

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
docker debug dhi.io/blackbox-exporter:<tag>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:blackbox-exporter \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/blackbox-exporter:<tag> /dbg/bin/sh
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
