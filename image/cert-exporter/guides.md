## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## About this cert-exporter image

This Docker Hardened cert-exporter image includes:

- The `cert-exporter` binary built from source from the official joe-elliott/cert-exporter releases
- A Prometheus metrics endpoint served on port 8080 at `/metrics` by default
- Support for parsing x509 certificates from mounted directories (PEM and PKCS#12), kubeconfig files, Kubernetes
  secrets, configmaps, admission webhooks, and cert-manager `CertificateRequest` resources
- The entrypoint is the cert-exporter binary at `/usr/local/bin/cert-exporter`

## Common cert-exporter Hardened Image use cases

This guide provides practical examples for using the cert-exporter Hardened Image to monitor x509 certificate expiration
in Kubernetes clusters or standalone environments.

### Run a cert-exporter container

#### Watch a certificate directory

```bash
docker run -d --name cert-exporter \
    -p 8080:8080 \
    -v /path/to/certs:/certs:ro \
    dhi.io/cert-exporter:<tag> \
    '--include-cert-glob=/certs/*.pem'
```

#### With a custom listen address

```bash
docker run -d --name cert-exporter \
    -p 9090:9090 \
    -v /path/to/certs:/certs:ro \
    dhi.io/cert-exporter:<tag> \
    '--include-cert-glob=/certs/*.pem' \
    --prometheus-listen-address=:9090
```

### Run with Docker Compose

#### Monitor a certificate directory

1. Create `docker-compose.yaml`:

```yaml
services:
  cert-exporter:
    image: dhi.io/cert-exporter:<tag>
    ports:
      - "8080:8080"
    volumes:
      - /etc/ssl/certs:/certs:ro
    command:
      - --include-cert-glob=/certs/*.pem
    restart: unless-stopped
```

2. Start the exporter:

```bash
docker compose up -d
```

3. Verify it's running:

```bash
curl http://localhost:8080/metrics | grep cert_exporter
```

### Integration with Prometheus

1. Create `docker-compose.yaml` with Prometheus:

```yaml
services:
  cert-exporter:
    image: dhi.io/cert-exporter:<tag>
    ports:
      - "8080:8080"
    volumes:
      - /etc/ssl/certs:/certs:ro
    command:
      - --include-cert-glob=/certs/*.pem
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - --config.file=/etc/prometheus/prometheus.yml
    depends_on:
      - cert-exporter
```

2. Create `prometheus.yml`:

```yaml
global:
  scrape_interval: 60s

scrape_configs:
  - job_name: 'cert-exporter'
    static_configs:
      - targets: ['cert-exporter:8080']
```

3. Start the stack:

```bash
docker compose up -d
```

4. Access Prometheus at `http://localhost:9090` and query certificate metrics:

```bash
# Certificates expiring in less than 30 days
cert_exporter_cert_expires_in_seconds < 86400 * 30

# Seconds until a certificate in a Kubernetes secret expires
cert_exporter_secret_expires_in_seconds
```

### Use cert-exporter in Kubernetes

Use the same container arguments in Kubernetes that you use with `docker run`. For example, mount certificate files and
scan them with:

```yaml
args:
  - --include-cert-glob=/host-certs/*.crt
ports:
  - name: metrics
    containerPort: 8080
readinessProbe:
  httpGet:
    path: /metrics
    port: metrics
```

To monitor Kubernetes secrets, grant the service account `get`, `list`, and `watch` permissions for secrets and pass
flags such as `--secrets-namespace=<namespace>` and `--secrets-include-glob=*.crt`. For Prometheus Operator, configure a
`ServiceMonitor` endpoint with `path: /metrics` and the metrics port.

## Common metrics

The exporter exposes Prometheus metrics for both certificate state and exporter health. Common metrics include:

| Metric                                        | Type    | Description                                                          |
| --------------------------------------------- | ------- | -------------------------------------------------------------------- |
| `cert_exporter_cert_expires_in_seconds`       | Gauge   | Number of seconds until a certificate on disk expires                |
| `cert_exporter_secret_expires_in_seconds`     | Gauge   | Number of seconds until a certificate in a Kubernetes secret expires |
| `cert_exporter_kubeconfig_expires_in_seconds` | Gauge   | Number of seconds until a certificate in a kubeconfig expires        |
| `cert_exporter_discovered`                    | Gauge   | Number of discovered certificates after include/exclude globs        |
| `cert_exporter_error_total`                   | Counter | Total number of unexpected errors encountered by the exporter        |

## Command-line options

Common command-line flags:

| Flag                                 | Description                                        | Default    |
| ------------------------------------ | -------------------------------------------------- | ---------- |
| `--include-cert-glob=<glob>`         | File globs to include when looking for certs       | -          |
| `--exclude-cert-glob=<glob>`         | File globs to exclude when looking for certs       | -          |
| `--include-kubeconfig-glob=<glob>`   | File globs to include when looking for kubeconfigs | -          |
| `--secrets-namespace=<ns>`           | Kubernetes namespace to list secrets               | -          |
| `--enable-webhook-cert-check`        | Enable admission webhook certificate checks        | `false`    |
| `--prometheus-path=<path>`           | Path to publish Prometheus metrics to              | `/metrics` |
| `--prometheus-listen-address=<addr>` | Address on which to bind and expose metrics        | `:8080`    |
| `--polling-period=<duration>`        | Periodic interval in which to check certs          | `1h`       |
| `--help`                             | Show help message                                  | -          |

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
