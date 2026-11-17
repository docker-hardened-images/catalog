## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/prometheuscommunity-stackdriver-exporter:<tag>`
- Mirrored image: `<your-namespace>/dhi-prometheuscommunity-stackdriver-exporter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Stackdriver Exporter image

Stackdriver Exporter reads time series from the Google Cloud Monitoring (formerly Stackdriver) API and exposes them for
Prometheus to scrape. This image is a drop-in replacement for `prometheuscommunity/stackdriver-exporter`: pass the same
flags you pass to that image. The exporter listens on port 9255.

The exporter needs at least one `--monitoring.metrics-prefixes` value and Google Application Default Credentials before
it listens. With no prefix it exits with status 1 and logs `metrics_prefixes must have at least one entry`. With a
prefix and no credentials it exits with status 1 and logs `could not find default credentials`.

### Basic usage

Show the version:

```bash
docker run --rm dhi.io/prometheuscommunity-stackdriver-exporter:<tag> --version
```

Mount a service-account key, set `GOOGLE_APPLICATION_CREDENTIALS` to its path, and name the project and metric prefix to
export. The service account needs the `roles/monitoring.viewer` role on the project. Create a key for it inside a
directory only your host user can open:

```bash
mkdir -m 0700 stackdriver-creds
gcloud iam service-accounts keys create stackdriver-creds/sa.json --iam-account=<service-account-email>
```

The runtime user is uid 65532, so the key file itself must be readable by that uid. The owner-only directory keeps other
host users away from the key, and the container sees only the one file it mounts:

```bash
chmod 0644 stackdriver-creds/sa.json
docker run -d --name stackdriver-exporter \
  -p 127.0.0.1:9255:9255 \
  -v "$(pwd)/stackdriver-creds/sa.json:/home/nonroot/sa.json:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/nonroot/sa.json \
  dhi.io/prometheuscommunity-stackdriver-exporter:<tag> \
  --google.project-ids=<project-id> \
  --monitoring.metrics-prefixes=compute.googleapis.com/instance/cpu
```

The metrics endpoint is unauthenticated, so the example publishes it on the loopback interface only. Each request to
`GET /metrics` makes the exporter query Cloud Monitoring and return the most recent point of every matching time series,
named `stackdriver_<resource type>_<metric type>`, for example
`stackdriver_gce_instance_compute_googleapis_com_instance_cpu_utilization`:

```bash
curl -fsS http://127.0.0.1:9255/metrics
```

Stop the container before the next example:

```bash
docker rm -f stackdriver-exporter
```

### With Docker Compose

Save the following as `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: stackdriver
    scrape_interval: 60s
    scrape_timeout: 30s
    static_configs:
      - targets: ["stackdriver-exporter:9255"]
```

Save the following as `compose.yaml` next to `prometheus.yml` and the `stackdriver-creds` directory:

```yaml
services:
  stackdriver-exporter:
    image: dhi.io/prometheuscommunity-stackdriver-exporter:<tag>
    environment:
      GOOGLE_APPLICATION_CREDENTIALS: /home/nonroot/sa.json
    volumes:
      - ./stackdriver-creds/sa.json:/home/nonroot/sa.json:ro
    command:
      - --google.project-ids=<project-id>
      - --monitoring.metrics-prefixes=compute.googleapis.com/instance/cpu
  prometheus:
    image: dhi.io/prometheus:<tag>
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
```

```bash
docker compose up -d
```

Prometheus reports the exporter target as `up` once it has scraped it:

```bash
curl -fsS -G http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=up{job="stackdriver"}'
```

```bash
docker compose down
```

### Environment variables

| Variable                         | Description                                                       | Default | Required                                        |
| -------------------------------- | ----------------------------------------------------------------- | ------- | ----------------------------------------------- |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to a service-account key file inside the container           | unset   | Yes, unless the host provides a metadata server |
| `HTTPS_PROXY`                    | Proxy for the calls to the Google OAuth and Cloud Monitoring APIs | unset   | No                                              |

## Common Stackdriver Exporter use cases

### Export several prefixes and filter time series

Repeat `--monitoring.metrics-prefixes` for each metric type prefix. `--monitoring.filters` takes `<prefix>:<filter>` and
adds the filter to every time series request for that prefix, using the
[Cloud Monitoring filter syntax](https://cloud.google.com/monitoring/api/v3/filters):

```bash
docker run -d --name stackdriver-exporter \
  -p 127.0.0.1:9255:9255 \
  -v "$(pwd)/stackdriver-creds/sa.json:/home/nonroot/sa.json:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/nonroot/sa.json \
  dhi.io/prometheuscommunity-stackdriver-exporter:<tag> \
  --google.project-ids=<project-id> \
  --monitoring.metrics-prefixes=compute.googleapis.com/instance/cpu \
  --monitoring.metrics-prefixes=loadbalancing.googleapis.com/https \
  '--monitoring.filters=compute.googleapis.com/instance/cpu:resource.labels.zone="us-central1-a"'
```

### Serve metrics over TLS with basic auth

`--web.config.file` enables TLS and basic auth on the exporter's listener, using the
[exporter-toolkit web configuration](https://github.com/prometheus/exporter-toolkit/blob/master/docs/web-configuration.md)
format. Passwords are bcrypt hashes, for example from `htpasswd -nBC 10 prometheus`. Put `tls.crt` and `tls.key` in
`stackdriver-creds` with mode 0644, the same way as the service-account key, and save the following as `web.yml`:

```yaml
tls_server_config:
  cert_file: /etc/stackdriver-exporter/tls.crt
  key_file: /etc/stackdriver-exporter/tls.key
basic_auth_users:
  prometheus: <bcrypt-hash>
```

```bash
docker run -d --name stackdriver-exporter \
  -p 9255:9255 \
  -v "$(pwd)/stackdriver-creds/sa.json:/home/nonroot/sa.json:ro" \
  -v "$(pwd)/web.yml:/etc/stackdriver-exporter/web.yml:ro" \
  -v "$(pwd)/stackdriver-creds/tls.crt:/etc/stackdriver-exporter/tls.crt:ro" \
  -v "$(pwd)/stackdriver-creds/tls.key:/etc/stackdriver-exporter/tls.key:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/nonroot/sa.json \
  dhi.io/prometheuscommunity-stackdriver-exporter:<tag> \
  --google.project-ids=<project-id> \
  --monitoring.metrics-prefixes=compute.googleapis.com/instance/cpu \
  --web.config.file=/etc/stackdriver-exporter/web.yml
```

Requests without the configured user get `401 Unauthorized`, and plain HTTP requests get `400 Bad Request`.

### Deploy with the upstream Helm chart

The `prometheus-community/prometheus-stackdriver-exporter` chart runs this image when you override its image values.
Create an image pull secret for `dhi.io` in the namespace first, then:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install stackdriver-exporter prometheus-community/prometheus-stackdriver-exporter \
  --namespace monitoring --create-namespace \
  --version <version> \
  --set image.repository=dhi.io/prometheuscommunity-stackdriver-exporter \
  --set image.tag=<tag> \
  --set 'image.pullSecrets[0]=<pull-secret>' \
  --set 'stackdriver.projectIds[0]=<project-id>' \
  --set 'stackdriver.metrics.prefixes[0]=compute.googleapis.com/instance/cpu' \
  --set-file stackdriver.serviceAccountKey=stackdriver-creds/sa.json
```

The chart runs `stackdriver_exporter` by name through `PATH`, which resolves in this image.

## Non-hardened images vs. Docker Hardened Images

| Item       | `prometheuscommunity/stackdriver-exporter`                                                              | Docker Hardened Image                                                                                                                                                                             |
| :--------- | :------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Entrypoint | `/bin/stackdriver_exporter`                                                                             | `/usr/local/bin/stackdriver_exporter`. `/bin/stackdriver_exporter` still resolves, so an entrypoint override that names it keeps working.                                                         |
| User       | `nobody` (uid 65534)                                                                                    | uid 65532 on runtime variants, root on `dev` variants. The exporter writes nothing to disk, so `--user 65534` also works.                                                                         |
| Home       | `/home`, so the default credentials file is `/home/.config/gcloud/application_default_credentials.json` | `/home/nonroot`. A key mounted at the upstream path is still found through a `/home/nonroot/.config/gcloud` link. With `--user 65534`, also set `HOME=/home` or `GOOGLE_APPLICATION_CREDENTIALS`. |
| Shell      | busybox `sh` and utilities                                                                              | None in runtime variants. Use a `dev` variant or [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/).                                                                             |
| Platforms  | `linux/amd64`, `linux/arm64`, `linux/arm/v7`, `linux/ppc64le`, `linux/riscv64`, `linux/s390x`           | `linux/amd64`, `linux/arm64`                                                                                                                                                                      |
| License    | `/LICENSE`                                                                                              | `/LICENSE`, plus `LICENSE` and `NOTICE` under `/usr/share/stackdriver-exporter/`                                                                                                                  |

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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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
