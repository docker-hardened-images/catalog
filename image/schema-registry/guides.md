## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/schema-registry:<tag>`
- Mirrored image: `<your-namespace>/dhi-schema-registry:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this schema-registry image

The container runs as default (`cmd`) `/etc/confluent/docker/run`, same as upstream. That script writes
`/etc/schema-registry/schema-registry.properties`, the logging configuration and `admin.properties` from the
`SCHEMA_REGISTRY_*` environment variables, waits for the Kafka brokers to answer, and then starts Schema Registry. There
is no `ENTRYPOINT`, so `docker run dhi.io/schema-registry:<tag> <command>` replaces the startup command instead of
adding to it.

Schema Registry listens on port 8081. Keystores and truststores can be mounted at `/etc/schema-registry/secrets`. The
default user is `appuser` (uid 1000, gid 1000), the same user the Confluent image runs as, and it owns
`/etc/schema-registry`, `/var/log/confluent` and its home directory.

The registry is built from the Confluent source at the release tag. The Avro, JSON Schema and Protobuf console producers
and consumers (`kafka-avro-console-producer` and the others), `register-deks`, `rewrap-deks` and
`schema-compatibility-check` are on the `PATH`, and the jars live under `/usr/share/java`. The launch scripts call `ub`,
Confluent's Go utility, which comes from the hardened `cp-docker-utils-1` package.

The 8.2 tags run Eclipse Temurin 21 and the 8.3 and 8.4 tags run Temurin 25, the same Java releases Confluent ships for
those lines. Every line publishes Debian 13 and Alpine 3.24 tags.

The environment variables the launch scripts read and what each Schema Registry setting does are covered by the
[Schema Registry configuration reference](https://docs.confluent.io/platform/current/schema-registry/installation/config.html)
and the
[Confluent Platform Docker configuration reference](https://docs.confluent.io/platform/current/installation/docker/config-reference.html).

### Run Schema Registry with Kafka

Start a single-node Kafka broker and Schema Registry on one network. The registry needs only `SCHEMA_REGISTRY_HOST_NAME`
and `SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS`; the container exits during startup with the name of the first one
that is missing. Port 8081 has no authentication here, so the example binds it to loopback.

```bash
$ docker network create schema-registry-net

$ docker run -d --name kafka --network schema-registry-net \
    -e KAFKA_NODE_ID=1 \
    -e KAFKA_PROCESS_ROLES=broker,controller \
    -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
    -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092 \
    -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka:9093 \
    -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
    dhi.io/kafka:4

$ docker run -d --name schema-registry --network schema-registry-net \
    -p 127.0.0.1:8081:8081 \
    -e SCHEMA_REGISTRY_HOST_NAME=schema-registry \
    -e SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:8081 \
    -e SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=PLAINTEXT://kafka:9092 \
    dhi.io/schema-registry:<tag>
```

The registry is ready when the REST API answers:

```bash
$ curl -s http://127.0.0.1:8081/subjects
[]
```

### Register and read a schema

Register an Avro schema under a subject, read it back, and check the compatibility level the registry applies to new
versions:

```bash
$ curl -s -X POST -H 'Content-Type: application/vnd.schemaregistry.v1+json' \
    --data '{"schema":"{\"type\":\"record\",\"name\":\"Order\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"}]}"}' \
    http://127.0.0.1:8081/subjects/orders-value/versions
{"id":1,"version":1,"guid":"<guid>","schemaType":"AVRO","schema":"..."}

$ curl -s http://127.0.0.1:8081/subjects/orders-value/versions/latest
$ curl -s http://127.0.0.1:8081/config
{"compatibilityLevel":"BACKWARD"}
```

Registering a version that breaks the compatibility rule, such as a new required field without a default, returns HTTP
409\.

### Produce and consume Avro records with the console tools

The console tools run inside the registry container and reach the broker and registry by their network names:

```bash
$ docker exec schema-registry bash -c "echo '{\"f\":\"hello\"}' | kafka-avro-console-producer \
    --bootstrap-server kafka:9092 --topic events \
    --property schema.registry.url=http://localhost:8081 \
    --property value.schema='{\"type\":\"record\",\"name\":\"Event\",\"fields\":[{\"name\":\"f\",\"type\":\"string\"}]}'"

$ docker exec schema-registry kafka-avro-console-consumer \
    --bootstrap-server kafka:9092 --topic events --from-beginning --max-messages 1 --timeout-ms 60000 \
    --property schema.registry.url=http://localhost:8081
{"f":"hello"}
```

The JSON Schema and Protobuf tools (`kafka-json-schema-console-producer`, `kafka-protobuf-console-consumer` and the
others) take the same flags.

### Expose Prometheus metrics

The Prometheus JMX exporter agent is at the path Confluent's image uses, so a `-javaagent` flag carried over from it
keeps working. The version matches Confluent's for the line: 0.20.0 on the 8.2 and 8.3 tags and 1.6.0 on the 8.4 tags.
Mount an exporter configuration and pass the agent through `SCHEMA_REGISTRY_OPTS`:

```bash
$ docker run -d --name schema-registry --network schema-registry-net \
    -p 127.0.0.1:8081:8081 -p 127.0.0.1:9404:9404 \
    -v "$PWD/jmx.yml:/tmp/jmx.yml:ro" \
    -e SCHEMA_REGISTRY_HOST_NAME=schema-registry \
    -e SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:8081 \
    -e SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=PLAINTEXT://kafka:9092 \
    -e SCHEMA_REGISTRY_OPTS=-javaagent:/usr/share/java/cp-base-new/jmx_prometheus_javaagent-1.6.0.jar=9404:/tmp/jmx.yml \
    dhi.io/schema-registry:8.4

$ curl -s http://127.0.0.1:9404/metrics | grep -m1 jvm_runtime_info
```

`jmx.yml` holds the exporter's rules, for example `rules: [{pattern: ".*"}]`. The same jars are also under
`/usr/share/java/cp-base-java-micro` (`cp-base-java` on the 8.2 tags), as in Confluent's image.

### FIPS variants

The `-fips` and `-fips-dev` tags ship a FIPS 140 cryptographic stack:

- The OpenSSL FIPS provider supplies OS-level cryptography for everything linking system OpenSSL.
- The Eclipse Temurin FIPS packages register the BouncyCastle FIPS providers through `JAVA_TOOL_OPTIONS` and ship the
  BCFIPS jars at `/usr/lib/bouncycastle`. Overriding `JAVA_TOOL_OPTIONS` removes the provider registration; overriding
  `JDK_JAVA_OPTIONS` drops the reflection exports and the trust store settings described below.
- `ub` comes from the `cp-docker-utils-1-fips` package, compiled with the Go FIPS 140 module.

The JVM starts in BouncyCastle's general mode, not approved-only mode: `JDK_JAVA_OPTIONS` carries
`-Dorg.bouncycastle.fips.approved_only=false` together with the BCFKS `cacerts` trust store of the FIPS JRE, because
Schema Registry loads PEM and PKCS12 key material, which BouncyCastle FIPS rejects in approved-only mode. For strict
approved-only mode, convert your keystores to BCFKS, point `SCHEMA_REGISTRY_OPTS` at them and set
`-Dorg.bouncycastle.fips.approved_only=true` there; `SCHEMA_REGISTRY_OPTS` lands after `JDK_JAVA_OPTIONS` on the `java`
command line, so the last setting wins.

### Add Confluent's licensed components

Confluent's image ships three directories from its licensed distribution, and this image does not:

- `/usr/share/java/schema-registry-plugins`: Schema Linking and the licensing support jars.
- `/usr/share/java/confluent-security`: the security plugins, such as role-based access control.
- `/usr/share/java/confluent-telemetry`: the telemetry reporter.

Confluent publishes these jars under the Confluent License Agreement, which gives Docker no right to redistribute them.
If your Confluent license covers these components, copy the directories out of Confluent's image of the same release and
mount them read-only. The 8.4 tags pair with `confluentinc/cp-schema-registry:8.4.1`; use the release that matches your
tag.

```bash
$ docker create --name confluent-sr confluentinc/cp-schema-registry:8.4.1

$ mkdir confluent-jars

$ for dir in schema-registry-plugins confluent-telemetry confluent-security; do \
    docker cp confluent-sr:/usr/share/java/$dir confluent-jars/$dir; \
  done

$ docker rm confluent-sr
```

Mount all three directories when you start the registry. The launch scripts already put them on the class path, so
nothing else changes:

```bash
$ docker run -d --name schema-registry --network schema-registry-net \
    -p 127.0.0.1:8081:8081 \
    -e SCHEMA_REGISTRY_HOST_NAME=schema-registry \
    -e SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:8081 \
    -e SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=PLAINTEXT://kafka:9092 \
    -v "$PWD/confluent-jars/schema-registry-plugins:/usr/share/java/schema-registry-plugins:ro" \
    -v "$PWD/confluent-jars/confluent-telemetry:/usr/share/java/confluent-telemetry:ro" \
    -v "$PWD/confluent-jars/confluent-security:/usr/share/java/confluent-security:ro" \
    dhi.io/schema-registry:8.4
```

Each feature still needs the settings Confluent documents for it. For Schema Linking on 8.4, add the exporter extension
and its update handler to the registry's environment; `GET /exporters` then answers:

```bash
    -e SCHEMA_REGISTRY_RESOURCE_EXTENSION_CLASS=io.confluent.dekregistry.DekRegistryResourceExtension,io.confluent.schema.exporter.SchemaExporterResourceExtension \
    -e SCHEMA_REGISTRY_KAFKASTORE_UPDATE_HANDLERS=io.confluent.schema.exporter.storage.SchemaExporterUpdateHandler \
```

Keep in mind:

- Mount the whole `confluent-security` directory. Its subdirectories link to each other, so mounting only one of them
  leaves broken links.
- The mounted directories carry their own copies of third-party libraries, and they load before the image's. Confluent's
  8.4 directories hold Guava 32.0.1 and Jackson 2.22.3, where the image carries newer patched versions, so the mounted
  copies win. The CVE fixes in this image do not apply to those libraries, and the image's scans do not cover the
  mounted jars.
- The image tests mount a stand-in jar at these three paths to prove the directories reach the class path. They do not
  run Confluent's jars.

## Differences from the Confluent image

Everything else is checked against Confluent's image of the same release in the image tests: the launch scripts in
`/etc/confluent/docker` are byte-identical and the scripts on the `PATH` differ only in the shebang line (`#!/bin/bash`
here, `#!/usr/bin/bash` there), the jars on the server's class path match artifact for artifact, the rendered
configuration files are identical for the same environment, and the REST API answers every request tested with the same
status and body. Two values differ by design: the version endpoint reports the public tag commit of the release as its
`commitId`, where Confluent's image reports an internal build commit, and the library jars this image raises to fix CVEs
carry newer versions than Confluent's.

- **Confluent's licensed jars are not included.** Confluent's image also carries
  `/usr/share/java/schema-registry-plugins`, `/usr/share/java/confluent-security` and
  `/usr/share/java/confluent-telemetry`, which Confluent publishes under the Confluent License Agreement. They are not
  redistributed here, so settings that load them, such as the schema exporter and importer, the security plugins and the
  telemetry reporter, have no effect until you mount the directories yourself. See
  [Add Confluent's licensed components](#add-confluents-licensed-components).

- **Use `docker stop` to stop the registry.** `schema-registry-stop` and `schema-registry-stop-service` read the process
  table with `ps`, so they work only on the dev variants, where `procps` is installed. The registry runs in the
  foreground and shuts down cleanly on SIGTERM.

- **This runtime tag has `bash`, unlike most Docker Hardened runtime images.** The Confluent launch scripts and the
  console tools are bash scripts, so it has to. Confluent's image has `bash` too, so nothing changes for you.

- **`LANG` is `en_US.UTF-8`.** Confluent's image sets `C.UTF-8`. Docker Hardened Images ship the `en_US` locale and
  select it by default; set `LANG=C.UTF-8` to match Confluent's image.

- **`/etc/schema-registry/secrets` exists and is writable by `appuser`.** Mounting a keystore directory on it works as
  it does with Confluent's image.

- **The sample `schema-registry.properties` and `log4j2.yaml` start empty.** Confluent's packages place samples in
  `/etc/schema-registry`; the launch scripts overwrite both on every start, so this image ships them as empty files
  owned by `appuser`, which lets the scripts do that without root.

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
