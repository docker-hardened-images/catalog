## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/spark-dependencies:<tag>`
- Mirrored image: `<your-namespace>/dhi-spark-dependencies:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this spark-dependencies image

This image contains a single storage-backend-specific shaded jar (all dependencies bundled) that runs an Apache Spark
job to analyze Jaeger spans and compute service dependency links. Which jar is included is fixed by the image **flavor**
(part of the tag):

| Flavor           | Storage backend                       |
| ---------------- | ------------------------------------- |
| `cassandra`      | Apache Cassandra                      |
| `elasticsearch7` | Elasticsearch 7.12–7.16               |
| `elasticsearch8` | Elasticsearch 7.17+ and 8.x           |
| `elasticsearch9` | Elasticsearch 9.x (matches `:latest`) |
| `opensearch`     | OpenSearch 2.x and 3.x                |

Unlike most Jaeger images, `STORAGE` does not need to be set — each flavor's jar already targets exactly one backend.

### Run the spark-dependencies container

This is a batch job: the container runs to completion and exits, rather than staying up as a service. By default it
processes all spans from the current UTC day; pass a `YYYY-mm-dd` date as the first argument (or set the `DATE`
environment variable) to process a different day.

Replace `<tag>` with the flavor and version you want to use (see
[What's included](#whats-included-in-this-spark-dependencies-image)).

#### Cassandra

```bash
docker run --rm \
  -e CASSANDRA_CONTACT_POINTS=cassandra-host1,cassandra-host2 \
  dhi.io/spark-dependencies:<tag>-cassandra
```

#### Elasticsearch

```bash
docker run --rm \
  -e ES_NODES=http://elasticsearch:9200 \
  dhi.io/spark-dependencies:<tag>-elasticsearch9
```

#### OpenSearch

```bash
docker run --rm \
  -e OS_NODES=http://opensearch:9200 \
  dhi.io/spark-dependencies:<tag>-opensearch
```

#### Process a specific day

```bash
docker run --rm \
  -e CASSANDRA_CONTACT_POINTS=cassandra-host1 \
  dhi.io/spark-dependencies:<tag>-cassandra \
  2026-08-01
```

### Environment variables

Common to every flavor:

| Variable                    | Description                                                                                                                               | Default        | Required |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------- |
| `DATE`                      | Date (`YYYY-mm-dd`) to compute dependency links for.                                                                                      | today (UTC)    | No       |
| `PEER_SERVICE_TAG`          | Tag name used to identify a peer service in spans.                                                                                        | `peer.service` | No       |
| `JAVA_OPTS`                 | Extra JVM options (heap sizing, trust store, and similar settings); forwarded by the entrypoint script, matching upstream's own launcher. | unset          | No       |
| `JAVA_TOOL_OPTIONS`         | Extra JVM options, picked up automatically by the JVM itself (standard JDK behavior) rather than via the entrypoint script.               | unset          | No       |
| `LOG4J_STATUS_LOGGER_LEVEL` | Log4j2 internal StatusLogger level (`OFF`, `DEBUG`, `INFO`, `WARN`, ...).                                                                 | `OFF`          | No       |

Cassandra flavor:

| Variable                                    | Description                      | Default         |
| ------------------------------------------- | -------------------------------- | --------------- |
| `CASSANDRA_CONTACT_POINTS`                  | Comma-separated Cassandra hosts. | `localhost`     |
| `CASSANDRA_KEYSPACE`                        | Keyspace to read/write.          | `jaeger_v1_dc1` |
| `CASSANDRA_LOCAL_DC`                        | Local datacenter to connect to.  | unset           |
| `CASSANDRA_USERNAME` / `CASSANDRA_PASSWORD` | Cassandra authentication.        | unset           |
| `CASSANDRA_USE_SSL`                         | Enable TLS to Cassandra.         | `false`         |

Elasticsearch flavors:

| Variable                      | Description                                                              | Default     |
| ----------------------------- | ------------------------------------------------------------------------ | ----------- |
| `ES_NODES`                    | Comma-separated Elasticsearch hosts advertising HTTP.                    | `127.0.0.1` |
| `ES_NODES_WAN_ONLY`           | Set to `true` when the cluster is not directly reachable (Docker/cloud). | `false`     |
| `ES_USERNAME` / `ES_PASSWORD` | Basic authentication credentials.                                        | unset       |
| `ES_INDEX_PREFIX`             | Prefix of Jaeger indices.                                                | unset       |
| `ES_TIME_RANGE`               | How far back to look for spans (date-math, max/default `24h`).           | `24h`       |

OpenSearch flavor:

| Variable   | Description                       | Default     |
| ---------- | --------------------------------- | ----------- |
| `OS_NODES` | Comma-separated OpenSearch hosts. | `127.0.0.1` |

See the [Jaeger Spark Dependencies README](https://github.com/jaegertracing/spark-dependencies#configuration) for the
complete list of configuration variables.

## Non-hardened images vs. Docker Hardened Images

Upstream's own image (`jaegertracing/spark-dependencies` on Docker Hub, last pushed in 2021) differs from this image in
several ways:

- **Entrypoint path**: upstream's `entrypoint.sh` lives at `/entrypoint.sh`; this image installs it at
  `/usr/local/bin/entrypoint.sh`, matching Docker Hardened Images convention.
- **Jar layout**: upstream builds one image per `VARIANT` build-arg and copies a single `app.jar` to `/app/app.jar`.
  This image's package stages all five backend jars under
  `/usr/share/spark-dependencies/spark-dependencies-<flavor>.jar`, and each flavor image sets `JAR_PATH` to its own jar
  at build time instead of a runtime build-arg.
- **Launch mechanism**: upstream's entrypoint runs `java -cp $JAR_PATH $MAIN_CLASS`, picking `$MAIN_CLASS` at container
  start via shell logic keyed on `$VARIANT_TYPE`. Each of this image's flavor jars already carries the correct
  `Main-Class` in its manifest, so the entrypoint runs `java -jar $JAR_PATH` directly - no variant-selection logic
  needed at runtime.
- **User**: upstream runs as `USER 185` and its entrypoint calls a `patch_uid()` function that appends an `/etc/passwd`
  entry for whatever arbitrary uid OpenShift's default restricted SCC assigns at runtime - Hadoop's
  `UserGroupInformation` needs a resolvable passwd entry for the running uid, or it can fail to determine the current
  user. This image runs as the standard Docker Hardened Images nonroot uid `65532` by default, which has a valid
  `/etc/passwd` entry baked in. That said, OpenShift's default restricted SCC overrides a container's uid with a
  randomly-assigned one regardless of what the image declares, so the same gap upstream's `patch_uid()` works around can
  still show up here too; this entrypoint has no equivalent patch, and writing `/etc/passwd` at container start isn't
  reliable on a read-only root filesystem anyway. If you deploy under the default restricted SCC, either grant the
  ServiceAccount the `anyuid` SCC (this image already runs as a fixed, known nonroot uid, so `anyuid` doesn't lower its
  security posture) or set `HADOOP_USER_NAME` explicitly so Hadoop doesn't need to resolve the uid via `/etc/passwd`.

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
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. **Exception for this image**: the runtime variant does include `bash` - see [No shell](#no-shell) below.                                         |

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

**Exception for this image**: the runtime variant does include `bash` - see [No shell](#no-shell) below for why.

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

**Exception for this image**: the runtime variant does include `bash`, since the entrypoint script needs shell logic to
forward the `JAVA_OPTS` environment variable and select the flavor's jar path at container start - neither is
expressible as a pure exec-form (`ENTRYPOINT ["java", ...]`) entrypoint without dropping `JAVA_OPTS` support.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
