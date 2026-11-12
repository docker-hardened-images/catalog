## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Solr image

The default `CMD` starts Solr in standalone mode on port `8983` as UID/GID `65532` (`solr`). Mount `/var/solr` for
persistence; the host directory must be owned by `65532:65532` before the container starts.

### Basic usage

```bash
docker run -d --name solr -p 8983:8983 dhi.io/solr:<tag>
```

Verify the node is up:

```bash
curl http://localhost:8983/solr/admin/info/system?wt=json
```

### With Docker Compose

```yaml
services:
  solr:
    image: dhi.io/solr:<tag>
    ports:
      - "8983:8983"
    volumes:
      - solr-data:/var/solr

volumes:
  solr-data:
```

### Environment variables

| Variable        | Description                                         | Default                   |
| --------------- | --------------------------------------------------- | ------------------------- |
| `SOLR_JAVA_MEM` | JVM heap size flags passed to the Solr start script | `-Xms512m -Xmx512m`       |
| `SOLR_OPTS`     | Additional JVM system properties                    | (empty)                   |
| `SOLR_HOME`     | Solr home directory for cores and configuration     | `/var/solr/data`          |
| `SOLR_LOGS_DIR` | Directory for Solr log files                        | `/var/solr/logs`          |
| `ZK_HOST`       | ZooKeeper connection string; enables SolrCloud mode | (unset)                   |
| `SOLR_INCLUDE`  | Path to the Solr environment include file           | `/etc/default/solr.in.sh` |

Refer to the [Apache Solr documentation](https://solr.apache.org/guide/solr/latest/) for full configuration and
operational reference.

## Common Solr use cases

### Create and query a core

`solr create` provisions a default configset; a bare `cores?action=CREATE` API call fails with
`Can't find resource 'solrconfig.xml'` because it expects the configset to already exist.

```bash
docker exec -it solr solr create -c demo

curl -X POST "http://localhost:8983/solr/demo/update?commit=true" \
  -H "Content-Type: application/json" \
  -d '[{"id": "1", "title": "Docker Hardened Solr", "category": "search"}]'

curl "http://localhost:8983/solr/demo/select?q=title:Solr&wt=json"
```

### SolrCloud with ZooKeeper

```yaml
services:
  zookeeper:
    image: zookeeper:3.9
    ports:
      - "2181:2181"
    environment:
      ZOO_MY_ID: 1

  solr-1:
    image: dhi.io/solr:<tag>
    ports:
      - "8983:8983"
    environment:
      ZK_HOST: zookeeper:2181
    depends_on:
      - zookeeper
    volumes:
      - solr-1-data:/var/solr

  solr-2:
    image: dhi.io/solr:<tag>
    ports:
      - "8984:8983"
    environment:
      ZK_HOST: zookeeper:2181
    depends_on:
      - zookeeper
    volumes:
      - solr-2-data:/var/solr

volumes:
  solr-1-data:
  solr-2-data:
```

Once both nodes are up, create a collection through the Collections API:

```bash
curl -X POST "http://localhost:8983/solr/admin/collections?action=CREATE&name=test&numShards=1&replicationFactor=2"
```

## Non-hardened images vs. Docker Hardened Images

The hardened Solr image differs from the upstream `solr` Docker Official Image in three ways that affect migration:

- **UID change** — Upstream runs as UID `8983`; DHI runs as UID `65532`. Bind-mounted data directories require
  `chown -R 65532:65532 <host-path>` before the container starts. Named Docker volumes do not need this step.
- **Optional Solr components removed** — `modules/`, `prometheus-exporter/`, and `cross-dc-manager/` are not present.
  None of these are loaded by Solr's default startup; removing them drops the vendored-Java CVE surface they bring in
  (Apache Tika, Hadoop/HDFS client, Kafka client, gRPC-Netty, etc.). If you need a specific module, copy the matching
  directory tree from the upstream Apache Solr release of the same version into `/opt/solr/` in a child image. For
  Prometheus metrics, run `apache/solr-prometheus-exporter` as a sidecar (the upstream-recommended deployment).
- **FIPS variants** — `JDK_JAVA_OPTIONS` is pre-set to load BouncyCastle FIPS from the bootclasspath and use a BCFKS
  trust store. `-Dorg.bouncycastle.fips.approved_only=false` is set deliberately: Solr's `CryptoKeys` RSA keypair
  generation uses a SecureRandom path that BC FIPS rejects under strict mode, which would otherwise prevent startup. The
  BC FIPS provider is still loaded and supplies all crypto; only the strict approved-algorithms gate is relaxed. If your
  Solr configuration references PKCS12 (`.p12`) or JKS (`.jks`) keystores, convert them to BCFKS with
  `keytool -importkeystore -srckeystore in.p12 -srcstoretype PKCS12 -destkeystore out.bcfks -deststoretype BCFKS -provider org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider -providerpath /opt/bouncycastle/bc-fips-*.jar`.

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

| Item               | Migration note                                                                                                                                                                                                                                                                             |
| :----------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                  |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                 |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                 |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                         |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Solr's default port 8983 is above 1024 and works without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                |
| UID change         | The upstream Solr image runs as UID 8983. Docker Hardened Solr runs as UID 65532. Bind-mounted data directories require `chown -R 65532:65532 <host-path>` before the container starts.                                                                                                    |

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
