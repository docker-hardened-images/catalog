## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/zipkin-slim:<tag>`
- Mirrored image: `<your-namespace>/dhi-zipkin-slim:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Zipkin Slim instance

Run Zipkin with in-memory storage:

```bash
$ docker run -d --name zipkin -p 127.0.0.1:9411:9411 dhi.io/zipkin-slim:<tag>
```

Port 9411 serves the UI, the query API and the collectors without authentication, so the examples publish it on the
loopback interface only. Publish it more widely only on a trusted network or behind an authenticating proxy.

Zipkin is ready when `/health` reports `UP`. The Lens UI is at `http://localhost:9411/zipkin/`.

```bash
$ curl -s http://localhost:9411/health
```

### Environment variables

| Variable                     | Description                                                                 | Default                                                                                 | Required                          |
| ---------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | --------------------------------- |
| `STORAGE_TYPE`               | Span storage: `mem` or `elasticsearch`                                      | `mem`                                                                                   | No                                |
| `MEM_MAX_SPANS`              | Spans the in-memory storage keeps                                           | `500000`                                                                                | No                                |
| `ES_HOSTS`                   | Comma-separated Elasticsearch URLs                                          | `http://localhost:9200`                                                                 | With `STORAGE_TYPE=elasticsearch` |
| `ES_USERNAME`, `ES_PASSWORD` | Elasticsearch basic authentication                                          | Not set                                                                                 | No                                |
| `ES_SSL_NO_VERIFY`           | Skip verification of the Elasticsearch TLS certificate                      | `false`                                                                                 | No                                |
| `QUERY_PORT`                 | Port for the UI, the API and the HTTP and gRPC collectors                   | `9411`                                                                                  | No                                |
| `SELF_TRACING_ENABLED`       | Trace Zipkin's own requests                                                 | `false`                                                                                 | No                                |
| `JAVA_OPTS`                  | JVM options that `start-zipkin` passes to Java, replacing the heap defaults | `-Xms160m -Xmx160m -XX:+ExitOnOutOfMemoryError` with in-memory storage, `64m` otherwise | No                                |

## Common Zipkin Slim use cases

### Send a span and read it back

The HTTP collector accepts Zipkin v2 JSON on `/api/v2/spans`, and the query API returns traces by ID:

```bash
$ curl -s -X POST http://localhost:9411/api/v2/spans -H 'Content-Type: application/json' \
  -d '[{"traceId":"5af7183fb1d4cf5f","id":"6b221d5bc9e6496c","name":"get /api","timestamp":1700000000000000,"duration":1500,"kind":"SERVER","localEndpoint":{"serviceName":"frontend"}}]'
$ curl -s http://localhost:9411/api/v2/trace/5af7183fb1d4cf5f
```

### Store spans in Elasticsearch

This Compose file starts a single Elasticsearch node, which serves HTTPS with a generated certificate, and points Zipkin
at it. `ES_SSL_NO_VERIFY` suits local testing only. For verified TLS, use upstream's
[trust store settings](https://github.com/openzipkin/zipkin/blob/master/zipkin-server/README.md#using-a-custom-key-store-or-trust-store-ssl);
the FIPS variants take a BCFKS trust store, as shown under [FIPS variants](#fips-variants).

```yaml
services:
  elasticsearch:
    image: dhi.io/elasticsearch:9
    environment:
      ELASTIC_PASSWORD: zipkin-example-password
      ES_JAVA_OPTS: -Xms512m -Xmx512m
  zipkin:
    image: dhi.io/zipkin-slim:<tag>
    ports:
      - "127.0.0.1:9411:9411"
    environment:
      STORAGE_TYPE: elasticsearch
      ES_HOSTS: https://elasticsearch:9200
      ES_USERNAME: elastic
      ES_PASSWORD: zipkin-example-password
      ES_SSL_NO_VERIFY: "true"
    depends_on:
      - elasticsearch
```

`/health` reports `UP` once Elasticsearch accepts requests.

### Set JVM options

`JAVA_OPTS` replaces the default heap settings:

```bash
$ docker run -d --name zipkin -p 127.0.0.1:9411:9411 \
  -e JAVA_OPTS="-Xms512m -Xmx512m -XX:+ExitOnOutOfMemoryError" \
  dhi.io/zipkin-slim:<tag>
```

### Scrape Prometheus metrics

```bash
$ curl -s http://localhost:9411/prometheus | grep zipkin_collector_spans_total
```

### Deploy with the Zipkin Helm chart

The [Zipkin Helm chart](https://github.com/openzipkin/zipkin-helm) runs this image. Point it at the hardened image and
the pull secret for `dhi.io`, and for FIPS tags add the `/tmp` volume shown under [FIPS variants](#fips-variants):

```bash
$ helm repo add zipkin https://zipkin.io/zipkin-helm
$ helm install zipkin zipkin/zipkin \
  --set image.repository=dhi.io/zipkin-slim \
  --set-string image.tag=<tag> \
  --set 'imagePullSecrets[0].name=<dhi-pull-secret>'
```

## Non-hardened images vs. Docker Hardened Images

- The runtime variants keep a shell, because `start-zipkin` is a shell script: `dash` on the Debian tags and busybox
  `sh` on the Alpine tags. They have no package manager.
- The image runs as `nonroot` (UID 65532) instead of `zipkin` (UID 1000). Zipkin writes nothing under `/zipkin`, so it
  runs under any UID, including the chart's `runAsUser: 1000`.
- There is no `HEALTHCHECK` and no `docker-healthcheck` script. Probe `GET /health` on port 9411 instead. In Compose,
  wait for Zipkin with `condition: service_started`, or on the Alpine tags add a healthcheck that runs
  `wget -qO- http://127.0.0.1:9411/health`; the Debian tags have no HTTP client.
- The Pulsar collector is not included, matching the slim distribution upstream documents. `PULSAR_*` settings are
  ignored; send spans over HTTP or gRPC.

### FIPS variants

FIPS variants run Bouncy Castle FIPS in approved-only mode for the JVM and OpenSSL with its FIPS provider.

- `JDK_JAVA_OPTIONS` holds the FIPS settings. Pass JVM options with `JAVA_OPTS`.

- `ES_SSL_NO_VERIFY` has no effect, because the JVM trust store is set. To use an Elasticsearch certificate signed by
  your own CA, import the CA into a BCFKS trust store and pass it to Zipkin. `keytool` does not read `JDK_JAVA_OPTIONS`,
  so the command puts Bouncy Castle FIPS and its JENT entropy source on its boot class path in approved-only mode (on
  the Alpine tags, whose JRE does not use JENT, leave out `:/usr/lib/bouncycastle/current/bc-rng-jent.jar`):

  ```bash
  $ docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/certs" --entrypoint keytool dhi.io/zipkin-slim:<tag>-fips \
    -J-Xbootclasspath/a:/usr/lib/bouncycastle/current/bc-fips.jar:/usr/lib/bouncycastle/current/bc-rng-jent.jar \
    -J-Dorg.bouncycastle.fips.approved_only=true \
    -importcert -noprompt -alias elasticsearch -file /certs/http_ca.crt \
    -keystore /certs/elasticsearch.bcfks -storetype BCFKS -storepass zipkin-truststore
  $ docker run -d --name zipkin -p 127.0.0.1:9411:9411 --network <network> -v "$PWD:/certs:ro" \
    -e STORAGE_TYPE=elasticsearch -e ES_HOSTS=https://elasticsearch:9200 \
    -e ES_USERNAME=elastic -e ES_PASSWORD=zipkin-example-password \
    dhi.io/zipkin-slim:<tag>-fips \
    --zipkin.storage.elasticsearch.ssl.trust-store=/certs/elasticsearch.bcfks \
    --zipkin.storage.elasticsearch.ssl.trust-store-password=zipkin-truststore \
    --zipkin.storage.elasticsearch.ssl.trust-store-type=BCFKS
  ```

- To serve HTTPS, follow upstream's
  [TLS/SSL settings](https://github.com/openzipkin/zipkin/blob/master/zipkin-server/README.md#tlsssl) with the key in a
  BCFKS key store and `--armeria.ssl.key-store-type=BCFKS`. Create the key store the same way, in approved-only mode:

  ```bash
  $ docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/certs" --entrypoint keytool dhi.io/zipkin-slim:<tag>-fips \
    -J-Xbootclasspath/a:/usr/lib/bouncycastle/current/bc-fips.jar:/usr/lib/bouncycastle/current/bc-rng-jent.jar \
    -J-Dorg.bouncycastle.fips.approved_only=true \
    -genkeypair -noprompt -alias zipkin -keyalg RSA -keysize 2048 -validity 365 \
    -dname CN=<hostname> -ext SAN=dns:<hostname> \
    -keystore /certs/zipkin.bcfks -storetype BCFKS -storepass zipkin-keystore -keypass zipkin-keystore
  $ docker run -d --name zipkin -p 127.0.0.1:9411:9411 -v "$PWD:/certs:ro" dhi.io/zipkin-slim:<tag>-fips \
    --armeria.ssl.enabled=true --armeria.ssl.key-store=/certs/zipkin.bcfks --armeria.ssl.key-store-type=BCFKS \
    --armeria.ssl.key-store-password=zipkin-keystore --armeria.ssl.key-alias=zipkin \
    '--armeria.ports[0].port=9411' '--armeria.ports[0].protocols[0]=https'
  ```

- A writable `/tmp` must allow executables, because Bouncy Castle FIPS loads native libraries from it. Docker mounts
  `--tmpfs /tmp` as `noexec` unless you pass `--tmpfs /tmp:exec`. The Debian variants also need `/tmp` writable for
  their entropy source, so with a read-only root filesystem mount one with `--tmpfs /tmp:exec` or these Helm values:

  ```yaml
  volumes:
    - name: tmp
      emptyDir: {}
  volumeMounts:
    - name: tmp
      mountPath: /tmp
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
