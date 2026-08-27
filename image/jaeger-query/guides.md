## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/jaeger-query:<tag>`
- Mirrored image: `<your-namespace>/dhi-jaeger-query:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this jaeger-query image

This image contains the Jaeger v2 unified binary (`/usr/bin/jaeger`) running in query-service mode. The query service
exposes the Jaeger UI — an embedded React web interface for searching and analyzing distributed traces — on port 16686,
alongside the query HTTP and gRPC APIs. The upstream Jaeger query configuration is shipped at
`/etc/jaeger/config-query.yaml` (fetched from the matching upstream release at build time). It expects a remote storage
backend reachable over gRPC at `localhost:17271`, so for the service to return traces you must provide that backend or
your own configuration — see [Point at production storage](#point-at-production-storage).

In Jaeger v2, the query service, collector, and all-in-one modes are all the same binary — the operating mode is
determined entirely by the configuration file. The standalone v1 `jaeger-query` image reached end-of-life at the end of
2025; this image is its v2 successor.

### Run the jaeger-query container

Run the following command, replacing `<tag>` with the image variant you want to use. The query service starts and serves
the UI even without a storage backend, but it will have nothing to query until one is configured (see
[Point at production storage](#point-at-production-storage)).

```bash
docker run -d --name jaeger-query \
  -p 16686:16686 \
  -p 16685:16685 \
  -p 8888:8888 \
  dhi.io/jaeger-query:<tag>
```

Once running, open `http://localhost:16686` in your browser to access the Jaeger UI.

To inspect available CLI flags, run:

```bash
docker run --rm dhi.io/jaeger-query:<tag> --help
```

To print the binary version:

```bash
docker run --rm dhi.io/jaeger-query:<tag> --version
```

## Point at production storage

The shipped configuration points `jaeger_storage` at a remote gRPC backend (`localhost:17271`) — the same default the
upstream Jaeger query config uses. For most deployments you will provide your own configuration file that points
`jaeger_storage` at your persistent backend, and pass it to the container with `--config /path/to/config.yaml`.

The following example uses an Elasticsearch backend. Mount your config file into the container and override the default
config path:

```bash
docker run -d --name jaeger-query \
  -p 16686:16686 \
  -p 16685:16685 \
  -v $(pwd)/config-query.yaml:/etc/jaeger/config-query.yaml:ro \
  dhi.io/jaeger-query:<tag>
```

A minimal `config-query.yaml` targeting an Elasticsearch cluster looks like the following. Adjust the `endpoints`,
`index_prefix`, and any TLS settings for your environment.

```yaml
service:
  extensions: [jaeger_storage, jaeger_query, healthcheckv2]
  pipelines:
    traces:
      receivers: [nop]
      processors: [batch]
      exporters: [nop]
  telemetry:
    resource:
      service.name: jaeger-query
    metrics:
      level: detailed
      readers:
        - pull:
            exporter:
              prometheus:
                host: 0.0.0.0
                port: 8888
    logs:
      level: info

extensions:
  healthcheckv2:
    use_v2: true
    http:
      endpoint: 0.0.0.0:13133

  jaeger_query:
    storage:
      traces: es_storage

  jaeger_storage:
    backends:
      es_storage:
        elasticsearch:
          endpoints:
            - https://elasticsearch:9200
          index_prefix: jaeger
          tls:
            insecure_skip_verify: false

receivers:
  nop:

processors:
  batch:

exporters:
  nop:
```

For the full list of supported backends (Cassandra, OpenSearch, ClickHouse, Badger, remote-storage gRPC) and their
configuration options, see the
[Jaeger v2 storage backends documentation](https://www.jaegertracing.io/docs/2.19/storage/).

## Health checks

The query service exposes a health endpoint on port **13133** via the OpenTelemetry Collector `healthcheckv2` extension.
Use `GET /status` for liveness and readiness probes — a healthy response returns HTTP 200 with a JSON body such as
`{"healthy":true,...}`.

The upstream configuration leaves the health endpoint at its default bind address, which listens on **localhost only**,
so it is not reachable from outside the container as shipped. To probe it externally (for example with Kubernetes
`httpGet` probes against the published port), bind it to all interfaces by overriding the endpoint at startup:

```bash
docker run -d --name jaeger-query \
  -p 13133:13133 \
  dhi.io/jaeger-query:<tag> \
  --config /etc/jaeger/config-query.yaml \
  --set extensions::healthcheckv2::http::endpoint=0.0.0.0:13133
```

With that override in place, the following Kubernetes probes work against the published port:

```yaml
livenessProbe:
  httpGet:
    path: /status
    port: 13133
  initialDelaySeconds: 5
  periodSeconds: 15

readinessProbe:
  httpGet:
    path: /status
    port: 13133
  initialDelaySeconds: 5
  periodSeconds: 10
```

The runtime image is minimal: it contains no shell and no HTTP client such as `wget` or `curl`, so it cannot run a
self-contained Docker `HEALTHCHECK`. Probe the `/status` endpoint from outside the container instead — for example with
the Kubernetes `httpGet` probe shown above — once the endpoint is bound to all interfaces as shown.

## Prometheus self-telemetry

The query service exposes its own internal OpenTelemetry Collector metrics on port **8888** at the `/metrics` path in
Prometheus exposition format. These metrics cover the health and performance of the query service itself — for example,
request latency and storage operation counts.

Add the following scrape target to your Prometheus configuration to collect them:

```yaml
scrape_configs:
  - job_name: jaeger-query
    static_configs:
      - targets: ['jaeger-query:8888']
```

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
