## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Run the beat-exporter container

Print version information:

```bash
docker run --rm dhi.io/beat-exporter:<tag> -version
```

Start the exporter pointing at a Beat running on the Docker host:

```bash
docker run --rm -p 9479:9479 \
  dhi.io/beat-exporter:<tag> \
  -beat.uri http://host.docker.internal:5066
```

Verify that metrics are being served:

```bash
curl http://localhost:9479/metrics
```

> **Note:** beat-exporter uses Go's `flag` package. All flags use a single dash (for example, `-beat.uri`), not the GNU
> double-dash convention (`--beat.uri`).

### Configuration

beat-exporter is configured entirely through command-line flags. There are no environment variables or configuration
files.

| Flag                  | Default                 | Description                                            |
| :-------------------- | :---------------------- | :----------------------------------------------------- |
| `-version`            | —                       | Print version and exit.                                |
| `-web.listen-address` | `:9479`                 | Address on which to expose Prometheus metrics.         |
| `-web.telemetry-path` | `/metrics`              | Path under which to expose metrics.                    |
| `-beat.uri`           | `http://localhost:5066` | URI of the Beat HTTP monitoring endpoint to scrape.    |
| `-beat.timeout`       | `10s`                   | Timeout for requests to the Beat endpoint.             |
| `-beat.system`        | `false` (flag absent)   | When present, expose system-level stats from the Beat. |
| `-tls.certfile`       | —                       | Path to the TLS certificate file (enables HTTPS).      |
| `-tls.keyfile`        | —                       | Path to the TLS private key file (enables HTTPS).      |

### Run with Docker Compose alongside Filebeat

The following Compose file starts Filebeat and beat-exporter together. Adjust the Filebeat image tag and configuration
mount to match your environment.

```yaml
services:
  filebeat:
    image: docker.elastic.co/beats/filebeat:<filebeat-tag>
    user: root
    volumes:
      - ./filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/log:/var/log:ro
    ports:
      - "5066:5066"

  beat-exporter:
    image: dhi.io/beat-exporter:<tag>
    command: ["-beat.uri", "http://filebeat:5066"]
    ports:
      - "9479:9479"
    depends_on:
      - filebeat
    restart: on-failure
```

Start the stack:

```console
$ docker compose up -d
```

Verify the metrics endpoint:

```console
$ curl http://localhost:9479/metrics | grep beat_
```

### Run with Prometheus scrape configuration

Add a scrape job to your `prometheus.yml` to collect beat-exporter metrics:

```yaml
scrape_configs:
  - job_name: beat-exporter
    static_configs:
      - targets:
          - beat-exporter:9479
```

### Enable TLS termination

To serve metrics over HTTPS, mount your certificate and key files and pass the corresponding flags:

```bash
docker run --rm -p 9479:9479 \
  -v /path/to/cert.pem:/etc/beat-exporter/cert.pem:ro \
  -v /path/to/key.pem:/etc/beat-exporter/key.pem:ro \
  dhi.io/beat-exporter:<tag> \
  -beat.uri http://localhost:5066 \
  -tls.certfile /etc/beat-exporter/cert.pem \
  -tls.keyfile /etc/beat-exporter/key.pem
```

### Use beat-exporter in Kubernetes

To use the beat-exporter hardened image in Kubernetes, [set up authentication](https://docs.docker.com/dhi/how-to/k8s/)
and apply a deployment manifest. The example below runs beat-exporter as a sidecar alongside Filebeat in a shared pod so
that `localhost:5066` resolves to Filebeat's monitoring endpoint.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filebeat
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: filebeat
  template:
    metadata:
      labels:
        app: filebeat
    spec:
      containers:
        - name: filebeat
          image: docker.elastic.co/beats/filebeat:<filebeat-tag>
          ports:
            - containerPort: 5066
              name: monitoring

        - name: beat-exporter
          image: dhi.io/beat-exporter:<tag>
          args:
            - -beat.uri
            - http://localhost:5066
          ports:
            - containerPort: 9479
              name: metrics
      imagePullSecrets:
        - name: <your-registry-secret>
---
apiVersion: v1
kind: Service
metadata:
  name: beat-exporter
  namespace: default
  labels:
    app: filebeat
spec:
  ports:
    - port: 9479
      targetPort: 9479
      name: metrics
  selector:
    app: filebeat
```

Apply the manifest:

```console
$ kubectl apply -n default -f filebeat.yaml
```

Verify the deployment:

```console
$ kubectl get pods -n default
```

Access the metrics:

```console
$ kubectl port-forward -n default deployment/filebeat 9479:9479
$ curl http://localhost:9479/metrics | grep beat_
```

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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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
