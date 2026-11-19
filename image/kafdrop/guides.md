## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a kafdrop image

This image runs the [Kafdrop](https://github.com/obsidiandynamics/kafdrop) web UI for Apache Kafka on the Eclipse
Temurin 25 JRE. The UI and the Spring Boot actuator endpoints listen on port 9000. Tags without a distro suffix, such as
`4` or `4.3.1`, are Debian 13; Alpine 3.24 tags contain `alpine`, such as `4-alpine`.

### Basic usage

Point Kafdrop at one or more Kafka brokers with `KAFKA_BROKERCONNECT`. The brokers must be reachable from inside the
container, so `localhost` refers to the container itself, not to your host.

```bash
$ docker run -d --name kafdrop -p 127.0.0.1:9000:9000 \
  -e KAFKA_BROKERCONNECT=<host:port,host:port> \
  dhi.io/kafdrop:<tag>
```

Open http://localhost:9000. Kafdrop has no authentication of its own, and the UI can create and delete topics, so the
example publishes the port on the loopback interface only. Put an authenticating reverse proxy in front of Kafdrop
before you publish it on other interfaces.

The health endpoint is at `/actuator/health` on port 9000, which you can use as a liveness or readiness probe:

```bash
$ curl http://127.0.0.1:9000/actuator/health
```

To run with a read-only root file system (`--read-only`), give Kafdrop a writable `/tmp`, where its web server creates
its working directory: add `--tmpfs /tmp`. On FIPS tags use `--tmpfs /tmp:exec`, because the BouncyCastle FIPS provider
loads native libraries that it unpacks into `/tmp`, and Docker mounts a tmpfs without exec permission by default.

### With Docker Compose

This example runs a single-node Kafka broker in KRaft mode next to Kafdrop. Save it as `compose.yaml`:

```yaml
services:
  kafka:
    image: dhi.io/kafka:<tag>
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
  kafdrop:
    image: dhi.io/kafdrop:<tag>
    ports:
      - "127.0.0.1:9000:9000"
    environment:
      KAFKA_BROKERCONNECT: kafka:9092
    depends_on:
      - kafka
```

```bash
$ docker compose up -d
```

Then open http://localhost:9000.

### Environment variables

Kafdrop is a Spring Boot application, so it reads these variables itself:

| Variable                     | Description                                                                 | Default                |
| ---------------------------- | --------------------------------------------------------------------------- | ---------------------- |
| `KAFKA_BROKERCONNECT`        | Bootstrap list of Kafka `host:port` pairs.                                  | `localhost:9092`       |
| `SERVER_SERVLET_CONTEXTPATH` | Path prefix the UI is served under.                                         | `/`                    |
| `SERVER_PORT`                | Port of the web UI.                                                         | `9000`                 |
| `KAFKA_PROPERTIES_FILE`      | Kafka client properties file, for TLS and SASL settings.                    | `kafka.properties`     |
| `KAFKA_TRUSTSTORE_FILE`      | Truststore file; Kafdrop sets `ssl.truststore.location` when it exists.     | `kafka.truststore.jks` |
| `KAFKA_KEYSTORE_FILE`        | Keystore file for mutual TLS; Kafdrop sets `ssl.keystore.location` from it. | `kafka.keystore.jks`   |
| `SCHEMAREGISTRY_CONNECT`     | Schema Registry endpoint, for Avro and Protobuf messages.                   |                        |
| `JAVA_TOOL_OPTIONS`          | JVM options, such as heap size. See [Set JVM options](#set-jvm-options).    |                        |

Relative file paths resolve against the working directory, `/`. Other Kafdrop options, such as `--message.format` or
`--topic.deleteEnabled`, are passed as container arguments or as the matching Spring Boot environment variable, for
example `MESSAGE_FORMAT`. See the [Kafdrop README](https://github.com/obsidiandynamics/kafdrop) for the full list.

## Common kafdrop use cases

### Connect to a secured Kafka cluster

Kafdrop supports TLS and SASL connections through a Kafka client properties file. Create the file, mount it read-only,
and point `KAFKA_PROPERTIES_FILE` at it:

```bash
$ cat > kafka.properties <<'EOF'
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="<username>" password="<password>";
EOF
$ docker run -d --name kafdrop -p 127.0.0.1:9000:9000 \
  -v "$(pwd)/kafka.properties:/etc/kafdrop/kafka.properties:ro" \
  -e KAFKA_BROKERCONNECT=<host:port,host:port> \
  -e KAFKA_PROPERTIES_FILE=/etc/kafdrop/kafka.properties \
  dhi.io/kafdrop:<tag>
```

When the brokers use a private certificate authority, or require mutual TLS, also mount the truststore or keystore and
set `KAFKA_TRUSTSTORE_FILE` or `KAFKA_KEYSTORE_FILE` to its path in the container, for example
`-v /path/to/kafka.truststore.jks:/etc/kafdrop/kafka.truststore.jks:ro` with
`-e KAFKA_TRUSTSTORE_FILE=/etc/kafdrop/kafka.truststore.jks`. Put the store passwords in `kafka.properties`. Mounted
files must be readable by UID 65532.

On FIPS tags, approved-only mode refuses the key protection of PKCS12 and PEM key stores, and Kafdrop exits at startup:
a PKCS12 key store fails with `keystore password was incorrect`, and a PEM key store with
`PBEWithHmacSHA256AndAES_256 AlgorithmParameters not available`. Use a BCFKS keystore instead (`ssl.keystore.type=BCFKS`
with `ssl.keystore.password` and `ssl.key.password` in `kafka.properties`). JKS key stores and trust stores load, and a
PEM truststore (`ssl.truststore.type=PEM`) works. The same applies to Kafdrop's own HTTPS listener on FIPS tags: set
`SSL_ENABLED=true` and `SSL_KEY_STORE_TYPE=BCFKS`, and provide the certificate and key as PEM files through
`SERVER_SSL_CERTIFICATE` and `SERVER_SSL_CERTIFICATE_PRIVATE_KEY`.

Kafdrop loads extra JARs from `/extra-classes`, for example a SASL client callback handler. Mount a directory with the
JARs there, such as `-v "$(pwd)/extra-classes:/extra-classes:ro"`.

### Browse Protobuf messages

Kafdrop decodes Protobuf messages with descriptor files (`.desc`). Copy your descriptor files into a directory, mount
it, and pass the Kafdrop options as container arguments:

```bash
$ mkdir -p protodesc
$ cp <path-to-descriptors>/*.desc protodesc/
$ docker run -d --name kafdrop -p 127.0.0.1:9000:9000 \
  -v "$(pwd)/protodesc:/protodesc:ro" \
  -e KAFKA_BROKERCONNECT=<host:port,host:port> \
  dhi.io/kafdrop:<tag> --message.format=PROTOBUF --protobufdesc.directory=/protodesc/
```

The same options also work as environment variables: `-e MESSAGE_FORMAT=PROTOBUF -e PROTOBUFDESC_DIRECTORY=/protodesc/`.

### Set JVM options

The JVM reads `JAVA_TOOL_OPTIONS` natively. For example, to limit the heap:

```bash
$ docker run -d --name kafdrop -p 127.0.0.1:9000:9000 \
  -e KAFKA_BROKERCONNECT=<host:port,host:port> \
  -e JAVA_TOOL_OPTIONS="-Xms32M -Xmx64M" \
  dhi.io/kafdrop:<tag>
```

To expose JMX, set the `com.sun.management.jmxremote` system properties the same way. This example has no JMX
authentication, so it publishes the JMX port on the loopback interface only:

```bash
$ docker run -d --name kafdrop -p 127.0.0.1:9000:9000 -p 127.0.0.1:9010:9010 \
  -e KAFKA_BROKERCONNECT=<host:port,host:port> \
  -e JAVA_TOOL_OPTIONS="-Dcom.sun.management.jmxremote.port=9010 -Dcom.sun.management.jmxremote.rmi.port=9010 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=127.0.0.1" \
  dhi.io/kafdrop:<tag>
```

In FIPS variants, the image sets `JDK_JAVA_OPTIONS` to load the BouncyCastle FIPS provider in approved-only mode.
Setting `JAVA_TOOL_OPTIONS` as shown above keeps the provider. Replacing `JDK_JAVA_OPTIONS` removes the BouncyCastle
FIPS jars from the boot class path, so Kafdrop starts on the JDK's default providers with no BouncyCastle FIPS provider
at all. Read the image's value with:

```bash
$ docker pull dhi.io/kafdrop:<tag>
$ docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' dhi.io/kafdrop:<tag> | grep '^JDK_JAVA_OPTIONS='
```

### Deploy to Kubernetes with the upstream Helm chart

The Kafdrop repository ships a Helm chart in its `chart/` directory. The chart has no image pull secret setting, so
attach your `dhi.io` credentials to the namespace's default service account first, then install the chart with the image
overridden:

```bash
$ kubectl create namespace kafdrop
$ kubectl create secret docker-registry dhi-pull --namespace kafdrop \
  --docker-server=dhi.io --docker-username=<username> --docker-password=<access-token>
$ kubectl patch serviceaccount default --namespace kafdrop \
  -p '{"imagePullSecrets":[{"name":"dhi-pull"}]}'
$ git clone --branch <version> --depth 1 https://github.com/obsidiandynamics/kafdrop.git
$ helm upgrade -i kafdrop ./kafdrop/chart --namespace kafdrop \
  --set image.repository=dhi.io/kafdrop \
  --set image.tag=<tag> \
  --set kafka.brokerConnect=<host:port,host:port> \
  --set service.type=ClusterIP
$ kubectl port-forward --namespace kafdrop svc/kafdrop 9000:9000
```

`<version>` is the Kafdrop release, such as `4.3.1`. The chart defaults to a `NodePort` service, which would publish the
unauthenticated UI on every node, so the example switches it to `ClusterIP` and reaches the UI through
`kubectl port-forward` at http://localhost:9000. The chart's liveness and readiness probes use `/actuator/health`, which
this image serves. The chart values `jvm.opts`, `cmdArgs`, `kafka.properties`, `kafka.truststore`, `kafka.keystore`,
`jmx.port` and `host` have no effect with this image, because they feed the upstream startup script; see the next
section. `mountProtoDesc` still mounts its host path at `/protodesc/`, but the Protobuf options it adds through
`CMD_ARGS` are lost, and the chart has no value for container arguments or extra environment variables, so Protobuf
browsing cannot be turned on through the chart with this image. With the upstream image, the chart enables JMX on port
8686 by default. With this image, JMX stays off until you enable it through `JAVA_TOOL_OPTIONS`, as shown in
[Set JVM options](#set-jvm-options).

## Non-hardened images vs. Docker Hardened Images

The upstream `obsidiandynamics/kafdrop` image starts Kafdrop through the bash script `/kafdrop.sh`. This image has no
shell, so it starts `java` directly with the same JVM flags and the same `/extra-classes` loader path. Everything the
script did before starting Kafdrop is gone:

- **JVM options**: `JVM_OPTS` is not read. Set `JAVA_TOOL_OPTIONS` instead, for example
  `-e JAVA_TOOL_OPTIONS="-Xms32M -Xmx64M"`.
- **Kafdrop options**: `CMD_ARGS` is not read. Pass Kafdrop's options as container arguments, for example
  `docker run ... dhi.io/kafdrop:<tag> --message.format=PROTOBUF --protobufdesc.directory=/protodesc/`, or as Spring
  Boot environment variables, such as `MESSAGE_FORMAT=PROTOBUF`.
- **Base64-encoded connection files**: `KAFKA_PROPERTIES`, `KAFKA_TRUSTSTORE` and `KAFKA_KEYSTORE` are not decoded into
  files. Mount the files instead and point `KAFKA_PROPERTIES_FILE`, `KAFKA_TRUSTSTORE_FILE` and `KAFKA_KEYSTORE_FILE` at
  them, as shown in [Connect to a secured Kafka cluster](#connect-to-a-secured-kafka-cluster).
- **JMX**: `JMX_PORT` and `HOST` are not read. Enable JMX with the `-Dcom.sun.management.jmxremote` system properties in
  `JAVA_TOOL_OPTIONS`, as shown in [Set JVM options](#set-jvm-options).
- **Marathon variables**: `PORT0`, which set the JMX port, and `MARATHON_APP_RESOURCE_MEM`, which set the heap size, are
  not read. Set the JMX properties and `-Xms`/`-Xmx` in `JAVA_TOOL_OPTIONS` instead.
- **Startup banner**: the ASCII-art banner came from the upstream script and is not printed.
- **User**: the upstream image runs as root. This image runs as the nonroot user, UID 65532. Mounted files must be
  readable by that UID.
- **JAR path**: the application JAR is in `/usr/share/kafdrop`, as `kafdrop-<version>.jar` with the link `kafdrop.jar`,
  which the entrypoint runs. `/kafdrop` links to `/usr/share/kafdrop`, so the upstream path
  `/kafdrop/kafdrop-<version>.jar` still resolves.
- **Java runtime**: the image runs on the Eclipse Temurin 25 JRE.

Dev tags, such as `4-dev` or `4-alpine-dev`, run as root and add `bash`, `coreutils` and the system package manager
(`apt` on Debian, `apk` on Alpine). They use the same entrypoint.

FIPS tags, such as `4-fips` or `4-alpine-fips`, run on the Eclipse Temurin 25 JRE with the BouncyCastle FIPS provider,
which handles the Kafka client's TLS and SASL connections and the optional HTTPS listener. The JVM is the only
cryptographic consumer in the image; the OpenSSL FIPS provider is included for STIG compliance. The image sets
`JDK_JAVA_OPTIONS` to enable the provider in approved-only mode, so append to it rather than replacing it.

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
