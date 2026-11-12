## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/cp-zookeeper:<tag>`
- Mirrored image: `<your-namespace>/dhi-cp-zookeeper:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this cp-zookeeper image

The container runs as default (`cmd`) `/etc/confluent/docker/run`, same as upstream. That script writes
`/etc/kafka/zookeeper.properties` from the `ZOOKEEPER_*` environment variables and then starts the server. There is no
`ENTRYPOINT`, so `docker run dhi.io/cp-zookeeper:<tag> <command>` replaces the startup command instead of adding to it.

The server listens on 2181 for clients, 2888 for peers, and 3888 for leader election. The ZooKeeper AdminServer listens
on 8080. Data and transaction logs go to `/var/lib/zookeeper/data` and `/var/lib/zookeeper/log`. Keystores and
truststores can be mounted at `/etc/zookeeper/secrets`. The default user is `appuser` (uid 1000, gid 1000), the same
user the Confluent image runs as, and it owns all three directories.

To keep data across restarts, mount both `/var/lib/zookeeper/data` and `/var/lib/zookeeper/log`. Mounting only the data
directory loses recent writes: ZooKeeper records every change in the transaction log first and only writes a snapshot to
the data directory every 100000 transactions, so a restart replays an empty log over an older snapshot.

The launch scripts, the environment variables they read, and what each ZooKeeper setting does are covered by the
[Confluent Platform Docker configuration reference](https://docs.confluent.io/platform/7.9/installation/docker/config-reference.html)
and the [ZooKeeper administrator's guide](https://zookeeper.apache.org/doc/r3.8.6/zookeeperAdmin.html).

### Run the cp-zookeeper container

Set `ZOOKEEPER_CLIENT_PORT` or `ZOOKEEPER_SECURE_CLIENT_PORT`. The container exits during startup if neither is set.

```bash
$ docker run -d --name zookeeper \
    -p 2181:2181 \
    -e ZOOKEEPER_CLIENT_PORT=2181 \
    -e ZOOKEEPER_TICK_TIME=2000 \
    dhi.io/cp-zookeeper:<tag>
```

Check the server with `zookeeper-shell`. Apache ZooKeeper's own scripts are on the `PATH` as well, so
`zkCli.sh -server localhost:2181 ls /` does the same thing.

```bash
$ docker exec zookeeper zookeeper-shell localhost:2181 ls /
```

To print the ZooKeeper version instead of starting the server, replace the command.

```bash
$ docker run --rm dhi.io/cp-zookeeper:<tag> zookeeper-run-class org.apache.zookeeper.version.VersionInfoMain
```

### Run a multi-node ensemble

Give every node the same `ZOOKEEPER_SERVERS` list and its own `ZOOKEEPER_SERVER_ID`. Entries are
`host:peerPort:leaderPort` and are separated by semicolons. The position of an entry in the list is the server ID it
belongs to. The container writes the ID to `/var/lib/zookeeper/data/myid` before it starts the server.

```yaml
services:
  zookeeper-1:
    image: dhi.io/cp-zookeeper:<tag>
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_SERVER_ID: "1"
      ZOOKEEPER_CLIENT_PORT: "2181"
      ZOOKEEPER_TICK_TIME: "2000"
      ZOOKEEPER_SERVERS: "zookeeper-1:2888:3888;zookeeper-2:2888:3888;zookeeper-3:2888:3888"

  zookeeper-2:
    image: dhi.io/cp-zookeeper:<tag>
    environment:
      ZOOKEEPER_SERVER_ID: "2"
      ZOOKEEPER_CLIENT_PORT: "2181"
      ZOOKEEPER_TICK_TIME: "2000"
      ZOOKEEPER_SERVERS: "zookeeper-1:2888:3888;zookeeper-2:2888:3888;zookeeper-3:2888:3888"

  zookeeper-3:
    image: dhi.io/cp-zookeeper:<tag>
    environment:
      ZOOKEEPER_SERVER_ID: "3"
      ZOOKEEPER_CLIENT_PORT: "2181"
      ZOOKEEPER_TICK_TIME: "2000"
      ZOOKEEPER_SERVERS: "zookeeper-1:2888:3888;zookeeper-2:2888:3888;zookeeper-3:2888:3888"
```

Start the ensemble and read the mode each node picked. One node reports `leader` and the other two report `follower`.

```bash
$ docker compose up -d
$ docker compose exec zookeeper-1 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2181 && printf srvr >&3 && cat <&3' | grep Mode
```

### Check whether a server is ready

Confluent's `cub zk-ready` is not installed. Each check below reports the server as ready only once it answers on the
client port.

From outside the container, query the AdminServer. It listens on port 8080 unless `ZOOKEEPER_ADMIN_ENABLE_SERVER` turns
it off, and answers `200` with `{"command":"ruok","error":null}`.

```bash
$ docker run -d --name zookeeper \
    -p 2181:2181 -p 8080:8080 \
    -e ZOOKEEPER_CLIENT_PORT=2181 \
    -e ZOOKEEPER_TICK_TIME=2000 \
    dhi.io/cp-zookeeper:<tag>
$ curl http://localhost:8080/commands/ruok
```

In Kubernetes, use an `httpGet` probe against the same endpoint. The kubelet makes the request, so the container needs
no HTTP client.

```yaml
readinessProbe:
  httpGet:
    path: /commands/ruok
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
```

To check the client port instead of the admin port, use an `exec` probe. Every variant has `bash`, so this needs no
extra tools. It sends the `srvr` [four letter word](https://zookeeper.apache.org/doc/r3.8.6/zookeeperAdmin.html#sc_4lw)
through bash's `/dev/tcp`.

```yaml
readinessProbe:
  exec:
    command:
      - bash
      - -c
      - 'exec 3<>/dev/tcp/127.0.0.1/2181; printf "srvr" >&3; grep -q "^Mode: " <&3'
  initialDelaySeconds: 10
  periodSeconds: 10
```

The same command works as a Compose health check.

```yaml
services:
  zookeeper:
    image: dhi.io/cp-zookeeper:<tag>
    environment:
      ZOOKEEPER_CLIENT_PORT: "2181"
      ZOOKEEPER_TICK_TIME: "2000"
    healthcheck:
      test:
        - CMD
        - bash
        - -c
        - 'exec 3<>/dev/tcp/127.0.0.1/2181; printf "srvr" >&3; grep -q "^Mode: " <&3'
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s
```

`srvr` is the only four letter word the client port answers by default. Confluent's properties template has no entry for
`4lw.commands.whitelist`, so add others through the JVM options instead.

```yaml
    environment:
      KAFKA_OPTS: "-Dzookeeper.4lw.commands.whitelist=srvr,ruok"
```

## Differences from the Confluent image

- **Run Kafka's command-line tools from a Kafka image, not this one.** This image installs ZooKeeper on its own, so
  `kafka-topics`, `zookeeper-server-stop`, `zookeeper-security-migration` and the rest of the Kafka tools exit with
  `command not found`, and there is no `/usr/share/java/kafka` classpath.

- **Replace `cub zk-ready` with one of the checks in
  [Check whether a server is ready](#check-whether-a-server-is-ready).** This affects readiness probes, init containers
  and health checks carried over from the Confluent image. Left in place, `cub zk-ready` exits with `cub: not found`.
  `dub`, which the launch scripts use to write configuration files and check directory permissions, is installed.

- **Pass `-client-configuration <properties-file>` to `zookeeper-shell` instead of `-zk-tls-config-file`.** This affects
  TLS connections only. The old flag is not recognised: the shell connects, reads it as the command to run, and exits
  127 with `Command not found`. The property names differ too, so rewrite the file rather than copying it:

  | Confluent `-zk-tls-config-file` | Apache `-client-configuration` |
  | :------------------------------ | :----------------------------- |
  | `zookeeper.ssl.client.enable`   | `zookeeper.client.secure`      |
  | `zookeeper.ssl.truststore.*`    | `zookeeper.ssl.trustStore.*`   |
  | `zookeeper.ssl.keystore.*`      | `zookeeper.ssl.keyStore.*`     |

  ```properties
  zookeeper.client.secure=true
  zookeeper.ssl.trustStore.location=/etc/zookeeper/secrets/truststore.jks
  zookeeper.ssl.trustStore.password=changeit
  zookeeper.ssl.keyStore.location=/etc/zookeeper/secrets/keystore.jks
  zookeeper.ssl.keyStore.password=changeit
  ```

- **To supply your own logging configuration, mount a `logback.xml` and point `ZOOKEEPER_LOGBACK_CONFIG` at it.**
  `ZOOKEEPER_LOG4J_ROOT_LOGLEVEL` and `ZOOKEEPER_LOG4J_LOGGERS` keep working unchanged, so this only affects you if you
  mount a `log4j.properties` today. That file is still written to `/etc/kafka/log4j.properties`, but nothing reads it,
  so a mounted copy has no effect and no log4j appender can be registered.

- **If a log parser reads container output, see [Keep the Confluent log format](#keep-the-confluent-log-format).** Lines
  here follow Apache ZooKeeper's pattern, `%d{ISO8601} [myid:%X{myid}] - %-5p [%t:%C{1}@%L] - %m%n`, which adds the
  `myid`, thread and source line. A parser written for Confluent's `[%d] %p %m (%c)%n` stops matching.

- **Run as the default user, or pass `--user 1000`.** This affects deployments that pin an arbitrary uid with
  `--user <uid>:0`, which the Confluent image allows because it owns its data directories by group 0. Here those
  directories belong to `appuser` and its own group, so another uid cannot write them and the server exits during
  startup.

- **Start the server in the foreground: `zkServer.sh start-foreground`, or the image's own `zookeeper-server-start`.**
  The default `docker run` already does this, so it only matters if you call `zkServer.sh start` yourself, and only in
  the runtime variants; both `dev` variants work. Used anyway, `start` prints `FAILED TO START`, exits 1, and leaves no
  server running.

- **Leave snapshot compression at its default, or use the Debian variant if you need `snappy`.** The property
  `zookeeper.snapshot.compression.method` is unset by default, which works everywhere, so skip this unless you set it to
  `snappy`. On the Alpine variant that setting makes the server thread fail with `UnsatisfiedLinkError` and write an
  empty `snapshot.N.snappy`. The Debian variant is unaffected, and `zkCli.sh` works on both.

- **`zookeeper-server-start -daemon` runs in the foreground anyway.** The flag is accepted and a notice is printed. No
  change is needed: container runtimes supervise the process themselves.

- **This runtime tag has `bash`, unlike most Docker Hardened runtime images.** The Confluent launch scripts and the
  `zookeeper-*` wrappers are bash scripts, so it has to. Confluent's image has `bash` too, so nothing changes for you.

- **ZooKeeper is Apache ZooKeeper 3.8, the line Confluent Platform 7.6 through 7.9 bundle**, built from the Apache
  source. No change is needed.

### Keep the Confluent log format

Write a `logback.xml` with the Confluent pattern, mount it, and point `ZOOKEEPER_LOGBACK_CONFIG` at it:

```xml
<configuration>
  <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
    <encoder>
      <pattern>[%d] %p %m \(%c\)%n</pattern>
    </encoder>
  </appender>
  <root level="${zookeeper.root.logger:-INFO}">
    <appender-ref ref="CONSOLE" />
  </root>
</configuration>
```

```bash
$ docker run -d --name zookeeper \
    -p 2181:2181 \
    -e ZOOKEEPER_CLIENT_PORT=2181 \
    -e ZOOKEEPER_LOGBACK_CONFIG=/etc/kafka/custom-logback.xml \
    -v ./logback.xml:/etc/kafka/custom-logback.xml:ro \
    dhi.io/cp-zookeeper:<tag>
$ docker logs zookeeper | grep -m1 QuorumPeerConfig
[2026-01-01 00:00:00,000] INFO Reading configuration from: /etc/kafka/zookeeper.properties (org.apache.zookeeper.server.quorum.QuorumPeerConfig)
```

Three things to keep in mind:

- **Escape the parentheses as `\(` and `\)`.** Logback reads bare parentheses in a pattern as grouping. Copying
  Confluent's `(%c)%n` across unescaped drops the parentheses and the line break, and every record runs together on one
  line.
- **Keep `${zookeeper.root.logger:-INFO}` as the root level**, or `ZOOKEEPER_LOG4J_ROOT_LOGLEVEL` stops having an
  effect.
- **Mount the file into a writable directory**, such as `/etc/kafka`. `ZOOKEEPER_LOG4J_LOGGERS` is applied by writing a
  copy of the file next to it; if the directory is read-only the per-logger levels are dropped and only the root level
  applies. The file itself can be mounted read-only.

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

  On FIPS variants the ZooKeeper JVM uses the BouncyCastle FIPS providers, and the rest of the image uses the OpenSSL
  FIPS provider. The image sets `JDK_JAVA_OPTIONS` and `KAFKA_OPTS` to select them, so if you set either variable
  yourself, append to the value the image already provides. Replacing it starts ZooKeeper without the FIPS providers.

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
