## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/jaeger:<tag>`
- Mirrored image: `<your-namespace>/dhi-jaeger:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Jaeger image

This Docker Hardened Image ships the single Jaeger v2 unified binary, `jaeger`, at `/usr/local/bin/jaeger`. Jaeger v2 is
an OpenTelemetry Collector distribution; run with no arguments it starts in all-in-one mode with in-memory storage,
using the configuration embedded in the binary (no config file is shipped or required). In that mode it listens on:

- `4317` OTLP gRPC and `4318` OTLP HTTP - trace ingestion
- `16686` - web UI and the query API (including the v3 API under `/api/v3`)
- `5778` / `5779` - remote sampling configuration (HTTP / gRPC)
- `9411` Zipkin, `14268` Jaeger thrift-over-HTTP, `14250` Jaeger gRPC - additional collector receivers
- `13133` / `13132` - health check (HTTP / gRPC)

The image sets `JAEGER_LISTEN_HOST=0.0.0.0`, matching the upstream container image, so these endpoints are reachable
through published container ports and Kubernetes Services. You can override the variable when a deployment needs a
different bind address.

## Start Jaeger

Start the all-in-one image and open the UI at `http://localhost:16686`:

```console
$ docker run --rm \
  -p 16686:16686 -p 4317:4317 -p 4318:4318 -p 13133:13133 \
  dhi.io/jaeger:2
```

The container logs `using default All-in-One configuration with memory storage`, then
`Everything is ready. Begin running and processing data.` once startup is complete. Send OTLP traces to `localhost:4317`
(gRPC) or `localhost:4318` (HTTP) and view them in the UI. You can confirm the query API is serving with:

```console
$ curl -s http://localhost:16686/api/v3/services
{"services":[]}
```

(The list is empty until traces have been ingested.)

### Deploy on Kubernetes

The image is shell-less and runs as nonroot, so no security context changes are needed for a basic all-in-one
deployment. Pull it with an image pull secret that has access to your mirrored repository:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      imagePullSecrets:
        - name: dhi-pull-secret
      containers:
        - name: jaeger
          image: <your-namespace>/dhi-jaeger:2
          ports:
            - containerPort: 4317
            - containerPort: 4318
            - containerPort: 16686
          readinessProbe:
            httpGet:
              path: /
              port: 16686
```

Create the `dhi-pull-secret` in the same namespace with
`kubectl create secret docker-registry dhi-pull-secret --docker-server=... --docker-username=... --docker-password=...`.
Note that the all-in-one, in-memory deployment above is for a single replica; use a persistent storage backend for
production.

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature             | DOI (`jaegertracing/jaeger`) | DHI (`dhi.io/jaeger`)                    |
| ------------------- | ---------------------------- | ---------------------------------------- |
| User                | `10001`                      | `nonroot` (65532) (runtime/FIPS)         |
| Shell               | No                           | No (runtime/FIPS)                        |
| Package manager     | No                           | No (runtime/FIPS)                        |
| Binary path         | `/cmd/jaeger/jaeger-linux`   | `/usr/local/bin/jaeger`                  |
| Entrypoint          | `/cmd/jaeger/jaeger-linux`   | `jaeger`                                 |
| Zero CVE commitment | No                           | Yes                                      |
| FIPS variant        | No                           | Yes (FIPS + STIG)                        |
| Base OS             | Alpine-based                 | Docker Hardened Debian 13 or Alpine 3.24 |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

**Runtime variants** are designed to run Jaeger in production. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the application binary and TLS certificates

**Dev variants** include `dev` in the tag (for example, `2-dev`). They are intended for multi-stage Dockerfiles or
interactive troubleshooting. These images typically:

- Run as root
- Include a shell and Debian package manager (`apt`)
- Ship the same binary as the runtime image

**FIPS variants** include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

For debugging minimal runtime containers without a shell, you can use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to running containers.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or Kubernetes manifests. At
minimum, you must update the base image in your existing deployment to a Docker Hardened Image. Common changes:

| Item               | Migration note                                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base images with a Docker Hardened Image.                                                                                     |
| Package management | Non-dev images don't contain package managers. Use package managers only in images with a dev tag.                                         |
| Non-root user      | By default, non-dev images run as the nonroot user. Ensure necessary files and directories are accessible to the nonroot user.             |
| Multi-stage build  | Use dev-tagged images for build stages and non-dev images for runtime.                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default.                                                                       |
| Entry point        | Docker Hardened Images may have different entry points than upstream images. Inspect entry points and update your deployment if necessary. |
| No shell           | By default, non-dev images don't contain a shell. Use dev images in build stages and copy artifacts to the runtime stage.                  |

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers.

### Permissions

By default image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user.

### Entry point

Docker Hardened Images may have different entry points than upstream Jaeger images. Use `docker inspect` to inspect
entry points and update your deployment if necessary.
