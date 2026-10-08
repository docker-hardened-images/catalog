## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/cp-kafka:<tag>`
- Mirrored image: `<your-namespace>/dhi-cp-kafka:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this cp-kafka image

The container runs as default (`cmd`) `/etc/confluent/docker/run`, same as upstream. That script writes
`/etc/kafka/kafka.properties` and the logging configuration from the `KAFKA_*` environment variables and then starts the
broker. There is no `ENTRYPOINT`, so `docker run dhi.io/cp-kafka:<tag> <command>` replaces the startup command instead
of adding to it.

The broker listens on 9092. Data goes to `/var/lib/kafka/data`, logs to `/var/log/kafka`, and keystores and truststores
can be mounted at `/etc/kafka/secrets`. The default user is `appuser` (uid 1000, gid 1000), the same user the Confluent
image runs as, and it owns all three directories.

Kafka itself comes from the hardened `kafka-3.9` (7.9 tags) and `kafka-4.3` (8.3 tags) packages, built from the same
Apache source as `dhi/kafka` and matching the Apache releases Confluent Platform 7.9 and 8.3 build on. The Kafka
command-line tools are on the `PATH` under their Confluent names (`kafka-topics`, `kafka-storage`, and so on), and the
Apache scripts they wrap are at `/usr/share/kafka/bin/*.sh`. The jars live at `/usr/share/kafka/libs`, with
`/usr/share/java/kafka` as a symlink to them.

The 7.9 tags support ZooKeeper mode and KRaft and include `dub`, the Confluent utility their launch scripts use to write
configuration files and check directory permissions. The 8.x tags are KRaft-only and use `ub`, its Go replacement, from
the hardened `cp-docker-utils-1` package.

Both lines publish Debian 13 and Alpine 3.24 tags. The 7.9 Alpine tags build for `linux/amd64` only, because Temurin 17
has no aarch64 build on Alpine 3.24; every other tag is multi-arch.

The launch scripts, the environment variables they read, and what each Kafka setting does are covered by the
[Confluent Platform Docker configuration reference](https://docs.confluent.io/platform/current/installation/docker/config-reference.html).

### Run the cp-kafka container

Start a single-node KRaft broker that is its own controller. `CLUSTER_ID`, `KAFKA_PROCESS_ROLES`, the listener set and
the quorum voters are all required for this topology; the container exits during startup with the name of the first
missing variable.

```bash
$ docker run -d --name kafka \
    -p 9092:9092 \
    -e CLUSTER_ID=q1Sh-9_ISia_zwGINzRvyQ \
    -e KAFKA_NODE_ID=1 \
    -e KAFKA_PROCESS_ROLES=broker,controller \
    -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:29093 \
    -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:29093 \
    -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
    -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT \
    -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
    -e KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT \
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
    dhi.io/cp-kafka:<tag>
```

Create a topic and round-trip a record through it.

```bash
$ docker exec kafka kafka-topics --bootstrap-server localhost:9092 --create --topic quickstart --partitions 1 --replication-factor 1
$ docker exec kafka bash -c 'echo hello | kafka-console-producer --bootstrap-server localhost:9092 --topic quickstart'
$ docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic quickstart --from-beginning --max-messages 1
```

To print the Kafka version instead of starting the broker, replace the command. The tools report the Apache Kafka
version the tag bundles (3.9.x on the 7.9 tags, 4.3.x on the 8.3 tags), where Confluent's image reports its own `-ccs`
build string.

```bash
$ docker run --rm dhi.io/cp-kafka:<tag> kafka-topics --version
```

To keep topics and their data across restarts, mount `/var/lib/kafka/data`.

### Run a three-node KRaft cluster

Give every node the same `CLUSTER_ID` and the same `KAFKA_CONTROLLER_QUORUM_VOTERS` list, and its own `KAFKA_NODE_ID`.
The advertised listener of each node carries its service name.

```yaml
services:
  kafka-1:
    image: dhi.io/cp-kafka:<tag>
    ports:
      - "9092:9092"
    environment: &kafka-env
      CLUSTER_ID: q1Sh-9_ISia_zwGINzRvyQ
      KAFKA_NODE_ID: "1"
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka-1:29093,2@kafka-2:29093,3@kafka-3:29093
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:29093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-1:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: "3"

  kafka-2:
    image: dhi.io/cp-kafka:<tag>
    environment:
      <<: *kafka-env
      KAFKA_NODE_ID: "2"
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-2:9092

  kafka-3:
    image: dhi.io/cp-kafka:<tag>
    environment:
      <<: *kafka-env
      KAFKA_NODE_ID: "3"
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-3:9092
```

Start the cluster and confirm all three brokers registered.

```bash
$ docker compose up -d
$ docker compose exec kafka-1 kafka-broker-api-versions --bootstrap-server kafka-1:9092 | grep -c 'id: '
```

### Run in ZooKeeper mode (7.9 tags only)

The 7.9 tags run against a ZooKeeper ensemble when `KAFKA_ZOOKEEPER_CONNECT` is set and `KAFKA_PROCESS_ROLES` is not.
The startup scripts wait for ZooKeeper to answer before starting the broker, honoring `KAFKA_CUB_ZK_TIMEOUT` (default 40
seconds). That wait is a ZooKeeper client request, so the JAAS and TLS settings in `KAFKA_OPTS` apply to it; set
`ZOOKEEPER_SASL_ENABLED=FALSE` to keep `KAFKA_OPTS` out of the wait, as with the Confluent image. `KAFKA_LISTENERS` can
be omitted in this mode; it is derived from the advertised listeners. The 8.x tags are KRaft-only and exit with
`environment variable "KAFKA_PROCESS_ROLES" is not set`.

```yaml
services:
  zookeeper:
    image: dhi.io/zookeeper:3.8

  kafka:
    image: dhi.io/cp-kafka:7.9
    ports:
      - "9092:9092"
    environment:
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: "1"
```

`dhi.io/zookeeper` starts standalone with no configuration; any ZooKeeper 3.8 ensemble the broker can reach works the
same way.

### Check whether a broker is ready

Confluent's `cub kafka-ready` is not installed. Each check below reports the broker as ready only once it answers on the
client port. The 7.9 startup scripts still gate broker start on their internal ZooKeeper wait with the same
`KAFKA_CUB_ZK_TIMEOUT` contract.

From inside the container, ask the broker for its API versions. The command exits non-zero until the broker serves
requests.

```bash
$ docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092
```

That command starts a JVM on every probe. For a lighter readiness check, use bash's `/dev/tcp`; every variant has
`bash`.

```yaml
readinessProbe:
  exec:
    command:
      - bash
      - -c
      - 'exec 3<>/dev/tcp/127.0.0.1/9092'
  initialDelaySeconds: 10
  periodSeconds: 10
```

The same command works as a Compose health check.

```yaml
    healthcheck:
      test:
        - CMD
        - bash
        - -c
        - 'exec 3<>/dev/tcp/127.0.0.1/9092'
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s
```

The TCP check proves the listener is up; a broker can accept connections shortly before it finishes joining the cluster.
Where that distinction matters, use the `kafka-broker-api-versions` form.

### FIPS variants

The `-fips` and `-fips-dev` tags ship a FIPS 140 cryptographic stack on both lines:

- The OpenSSL FIPS provider supplies OS-level cryptography for everything linking system OpenSSL, including the
  Python-based configuration tooling on the 7.9 tags.
- The Eclipse Temurin FIPS packages register the BouncyCastle FIPS providers through `JAVA_TOOL_OPTIONS` and ship the
  BCFIPS jars at `/usr/lib/bouncycastle`; the FIPS Kafka package links them into `/usr/share/kafka/libs`. Overriding
  `JAVA_TOOL_OPTIONS` removes the provider registration; overriding `JDK_JAVA_OPTIONS` drops the reflection exports and
  the trust store settings described below.
- The FIPS Kafka package's log cleaner hashes with SHA-256 instead of MD5, so compaction keeps working in approved-only
  mode. The wider digest means a given `log.cleaner.dedupe.buffer.size` holds about 40% fewer offsets than on the other
  tags.
- On the 8.3 tags, `ub` comes from the `cp-docker-utils-1-fips` package, compiled with the Go FIPS 140 module.

The JVM starts in BouncyCastle's general mode, not approved-only mode: `JDK_JAVA_OPTIONS` carries
`-Dorg.bouncycastle.fips.approved_only=false` together with the BCFKS `cacerts` trust store of the FIPS JRE, because
Kafka loads PEM key and trust material through PKCS12, which BouncyCastle FIPS rejects in approved-only mode.
`KAFKA_OPTS` is left unset and stays available for JAAS configuration and agents, as upstream documents.

For strict approved-only mode, convert your keystores to BCFKS and set
`KAFKA_OPTS=-Dorg.bouncycastle.fips.approved_only=true`. `KAFKA_OPTS` lands after `JDK_JAVA_OPTIONS` on the `java`
command line, so the last setting wins while the trust store settings stay in place. `keytool` does not pick the
BouncyCastle FIPS provider up from the image environment, so pass it explicitly:

```bash
$ docker run --rm -v "$PWD/secrets:/etc/kafka/secrets" dhi.io/cp-kafka:8.3-fips-dev bash -c '
    "$JAVA_HOME/bin/keytool" -importkeystore \
    -providerclass org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider \
    -providerpath /usr/lib/bouncycastle/current/bc-fips.jar \
    -srcprovidername BCFIPS -destprovidername BCFIPS \
    -srckeystore /etc/kafka/secrets/kafka.keystore.p12 -srcstoretype PKCS12 -srcstorepass changeit \
    -destkeystore /etc/kafka/secrets/kafka.keystore.bcfks -deststoretype BCFKS -deststorepass changeit'
```

Reference the converted stores with the usual `KAFKA_SSL_KEYSTORE_FILENAME` and credentials variables, and set
`KAFKA_SSL_KEYSTORE_TYPE` and `KAFKA_SSL_TRUSTSTORE_TYPE` to `BCFKS`.

## Differences from the Confluent image

- **Expect the Apache Kafka version from the command-line tools.** `kafka-topics --version` and the other tools print
  the version of the bundled Apache Kafka build (3.9.x on the 7.9 tags, 4.3.x on the 8.3 tags), where Confluent's image
  prints `7.9.10-ccs` style build strings. The Confluent Platform version is the image tag. The jars in
  `/usr/share/java/kafka` carry Apache names without the `-ccs` suffix.

- **Kafka is the Apache release, not Confluent's fork.** Confluent's image builds Kafka from `confluentinc/kafka`, whose
  release tags add Apache-branch fixes newer than the bundled Apache release and Confluent patches to the clients,
  Connect, controller and raft code. This image runs the Apache release from the hardened `kafka-3.9`/`kafka-4.3`
  packages, built from the same source and patches as `dhi/kafka`, so those code changes are absent; brokers start
  through `kafka.Kafka` here as in Confluent's image.

- **Replace `cub kafka-ready` with one of the checks in
  [Check whether a broker is ready](#check-whether-a-broker-is-ready).** This affects readiness probes, init containers
  and health checks carried over from the Confluent image. Left in place, `cub kafka-ready` exits with
  `cub: command not found`. On the 7.9 tags the launch scripts' internal uses of cub are already replaced: the ZooKeeper
  wait runs `zookeeper-shell` against the connect string until a server answers, the listener derivation is a `sed` over
  `KAFKA_ADVERTISED_LISTENERS`, and `dub` is installed.

- **Use `kafka-leader-election` and `connect-mirror-maker` in place of the retired tools.**
  `kafka-preferred-replica-election` (all tags) and `kafka-mirror-maker` (8.3 tags) have no Apache script to wrap; run
  `kafka-leader-election --bootstrap-server <host:port> --election-type PREFERRED --all-topic-partitions` and
  MirrorMaker 2's `connect-mirror-maker` instead. `trogdor`, Kafka's fault-injection test framework, has no bare name;
  its script stays at `/usr/share/kafka/bin/trogdor.sh`.

- **Run as the default user, or pass `--user 1000`.** This affects deployments that pin an arbitrary uid with
  `--user <uid>:0`, which the Confluent image allows because it owns its data directories by group 0. Here those
  directories belong to `appuser` and its own group, so another uid cannot write them and the broker exits during
  startup.

- **Use `docker stop` to stop a broker.** `kafka-server-stop` reads the process table with `ps`, so it ships on the dev
  variants only, where `procps` is installed. The container path is `docker stop`: the broker runs in the foreground and
  shuts down cleanly on SIGTERM.

- **This runtime tag has `bash`, unlike most Docker Hardened runtime images.** The Confluent launch scripts and the
  Kafka tools are bash scripts, so it has to. Confluent's image has `bash` too, so nothing changes for you.

- **Java matches upstream per line.** The 7.9 tags run Temurin 17 and the 8.3 tags run Temurin 25, the same releases
  Confluent ships, so JVM flags carried over from the Confluent image keep working.

- **The environment starts clean.** Confluent's image bakes empty `CLUSTER_ID` and `KAFKA_ADVERTISED_LISTENERS` values
  (plus `KAFKA_ZOOKEEPER_CONNECT` on 7.9), which leak an empty `zookeeper.connect=` entry into the rendered
  configuration. This image leaves them unset; behavior once you set them is identical. Set `KAFKA_LOG4J_OPTS` yourself
  to point the JVM at your own logging file; when unset, the startup path uses the configuration rendered under
  `/etc/kafka`, same as upstream.

- **The log format matches upstream.** The rendered logging configuration comes from Confluent's own templates on both
  lines, so `KAFKA_LOG4J_ROOT_LOGLEVEL` and `KAFKA_LOG4J_LOGGERS` work unchanged and log parsers keep matching. Set
  `TRACE=true` to trace the launch scripts, same as upstream.

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
