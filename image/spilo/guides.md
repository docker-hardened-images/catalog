## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this spilo image

This Docker Hardened Spilo image ships the [Spilo](https://github.com/zalando/spilo) PostgreSQL HA appliance:

- Patroni with the kubernetes, etcd, consul, zookeeper, and aws extras at `/opt/spilo`
- PostgreSQL 17 as the primary server, with 14, 15, and 16 bundled under `/usr/lib/postgresql/` for in-place
  `pg_upgrade` migrations
- the full Spilo extension set on every bundled major, including PostGIS, TimescaleDB (Apache edition), pgvector,
  pg_partman, pglogical, pgaudit, pg_cron, and the Zalando monitoring extensions (bg_mon, pg_auth_mon, pg_mon)
- WAL-G for continuous archiving, base backups, and clone/restore bootstraps
- pgbouncer, enabled through `PGBOUNCER_CONFIGURATION`, and pgqd, which ticks the pgq queues on the primary
- the Spilo runtime: `/launch.sh` under dumb-init, runit service supervision, and the `/scripts` configuration and
  lifecycle tooling

The container starts as the `postgres` user (uid 70). `SCOPE` names the cluster; all other configuration arrives through
environment variables rendered into `/run/postgres.yml` at boot.

### Start a two-member cluster with etcd

```yaml
services:
  etcd:
    image: dhi.io/etcd:3
    environment:
      ETCD_LISTEN_CLIENT_URLS: http://0.0.0.0:2379
      ETCD_ADVERTISE_CLIENT_URLS: http://etcd:2379

  spilo-1:
    image: dhi.io/spilo:<tag>
    hostname: spilo-1
    environment: &spilo-env
      SCOPE: demo
      ETCD3_HOST: etcd:2379
      PGPASSWORD_SUPERUSER: <superuser-password>
      PGPASSWORD_STANDBY: <replication-password>
      SPILO_CONFIGURATION: "{postgresql: {parameters: {'bg_mon.listen_address': 0.0.0.0}}}"
    volumes:
      - spilo-1-data:/home/postgres/pgdata

  spilo-2:
    image: dhi.io/spilo:<tag>
    hostname: spilo-2
    environment: *spilo-env
    volumes:
      - spilo-2-data:/home/postgres/pgdata

volumes:
  spilo-1-data:
  spilo-2-data:
```

Patroni elects one member as the primary and configures streaming replication to the other. The Patroni REST API on port
8008 reports each member's role (`/primary`, `/replica`, `/readiness`), PostgreSQL listens on 5432, and the bg_mon
metrics endpoint answers on 8080.

`configure_spilo.py` auto-detects the bg_mon listen address and picks the IPv6 wildcard (`::`) whenever an IPv6 loopback
socket can be bound. On networks without a global IPv6 address (the Docker default bridge, IPv4-only Kubernetes
clusters) bg_mon's own bind of `::` then fails and the worker restarts in a loop without serving. Set
`bg_mon.listen_address: 0.0.0.0` under `postgresql.parameters` in `SPILO_CONFIGURATION` to pin it, as the examples in
this guide do.

### Kubernetes and the Zalando postgres-operator

Set the operator's `docker_image` (or the `SPILO_IMAGE` of your deployment tooling) to this image. The operator injects
`SCOPE`, `SPILO_CONFIGURATION`, and `DCS_ENABLE_KUBERNETES_API=true`; no etcd is needed because Patroni uses the
Kubernetes API as its DCS. Notes for this image:

- The image runs as uid 70 by default. Set `spilo_runasuser: 70`, `spilo_runasgroup: 70`, and `spilo_fsgroup: 70` in the
  operator configuration (or the equivalent securityContext) so mounted volumes are writable. Arbitrary other uids are
  not supported: /etc/passwd ships read-only, so run as uid 70 (or root in the dev variant).
- Mount the persistent volume at `/home/postgres/pgdata`.
- `/run` must be writable; on a read-only root filesystem mount an emptyDir there.
- The readiness probe is `GET /readiness` on port 8008.

### Configuration

The most common environment variables (`configure_spilo.py` renders them into the Patroni configuration; the full
contract is documented in [upstream ENVIRONMENT.rst](https://github.com/zalando/spilo/blob/master/ENVIRONMENT.rst)):

| Variable                                             | Description                                                   |
| ---------------------------------------------------- | ------------------------------------------------------------- |
| `SCOPE`                                              | Cluster name, identical across members (required)             |
| `PGVERSION`                                          | PostgreSQL major to bootstrap (default 17; 14-16 available)   |
| `ETCD3_HOST` / `ETCD3_HOSTS`                         | etcd v3 endpoint(s) for the DCS (`ETCD_*` selects the v2 API) |
| `DCS_ENABLE_KUBERNETES_API`                          | Use the Kubernetes API as the DCS                             |
| `SPILO_CONFIGURATION`                                | YAML merged into the rendered Patroni configuration           |
| `PGPASSWORD_SUPERUSER` / `PGPASSWORD_STANDBY`        | Credentials for the superuser and replication user            |
| `WAL_S3_BUCKET` / `WAL_GS_BUCKET` / `WALG_AZ_PREFIX` | Enable WAL-G archiving to S3 / GCS / Azure                    |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`        | Object-store credentials for backups                          |
| `WALG_S3_ENDPOINT`                                   | S3-compatible endpoint, `protocol+convention://host:port`     |
| `BACKUP_SCHEDULE` / `BACKUP_NUM_TO_RETAIN`           | Base-backup cron schedule (default 0 1 * * \*) and retention  |
| `CLONE_SCOPE` / `CLONE_*`                            | Bootstrap a new cluster from another cluster's backups        |
| `STANDBY_HOST` / `STANDBY_*`                         | Run as a standby cluster following another cluster            |
| `SSL_CERTIFICATE_FILE` / `SSL_PRIVATE_KEY_FILE`      | Server TLS material (see the warning below)                   |

Change the superuser, admin, and replication passwords in production: the upstream-compatible defaults
(`PGPASSWORD_SUPERUSER=zalando`, `PGPASSWORD_ADMIN=cola`, `PGPASSWORD_STANDBY=standby`) exist only for compatibility
with Zalando tooling.

If no TLS material is supplied, the image generates a self-signed certificate at boot with the upstream defaults: CN
`spilo.example.org` and a 30-day validity. Provide `SSL_CERTIFICATE_FILE`/`SSL_PRIVATE_KEY_FILE` (or the `_BASE64`
content variants) in production.

### Backups with WAL-G

Set an object-store target (for example `WAL_S3_BUCKET` plus AWS credentials) and Spilo archives WAL continuously and
takes a nightly base backup on `BACKUP_SCHEDULE`. Run WAL-G by hand through the rendered environment directory:

```console
envdir /run/etc/wal-e.d/env wal-g backup-list
envdir /run/etc/wal-e.d/env wal-g backup-push "$PGDATA"
```

New members bootstrap from backups automatically when `CLONE_SCOPE`/`CLONE_WAL_S3_BUCKET` point at an existing cluster's
archive. With an S3-compatible endpoint (`WALG_S3_ENDPOINT`), also set `WALG_DISABLE_S3_SSE: "true"` unless the endpoint
supports SSE: Spilo requests AES256 server-side encryption otherwise, and stores without a KMS refuse the upload.

The bundled PostgreSQL restricts logical decoding plugins to an allowlist. To use `wal2json` or `decoderbufs`, extend
it, for example through `SPILO_CONFIGURATION`:
`postgresql: {parameters: {output_plugin_libraries: 'pgoutput,test_decoding,wal2json,decoderbufs'}}`.

### In-place major upgrades

The image bundles PostgreSQL 14 through 17, so an existing cluster initialized on an older major boots unchanged (the
data directory's `PG_VERSION` file selects the binaries) and upgrades in place:

```console
PGVERSION=17 python3 /scripts/inplace_upgrade.py 2
```

on the primary member upgrades the whole cluster to PostgreSQL 17 with `pg_upgrade`, coordinated through Patroni.
`PGVERSION` selects the target major and the positional argument is the expected member count (primary plus replicas);
the script refuses to run when it does not match the running cluster.

### Migrating from ghcr.io/zalando/spilo-\*

- Upstream images run as root and own their data files as uid 101 (the postgres user of the upstream image; the operator
  examples set spilo_runasuser: 101); this image defaults to uid 70 and supports only that uid (or root in the dev
  variant). Chown the data volume to 70 when migrating.
- Upstream images are Ubuntu-based; this image is Debian 13 with glibc 2.41. Collation-sensitive text indexes built on
  other glibc versions can be silently corrupted by locale changes: after moving a cluster, run `REINDEX DATABASE` on
  databases with text indexes, or verify with amcheck. The upstream `USE_OLD_LOCALES` mechanism (an Ubuntu 18.04 locale
  archive) is not shipped.
- The embedded etcd of upstream's demo mode is not shipped; point `ETCD3_HOST` at a real DCS or use the Kubernetes API.
  `ETCD_HOST` selects the legacy etcd v2 API, which etcd 3.6+ no longer serves.
- The bundled wal-g is built without the optional brotli and lzo codecs. WAL archives and backups written by upstream
  release binaries with `WALG_COMPRESSION_METHOD: brotli` (or legacy lzo archives) cannot be restored by this image and
  report as missing; lz4 (the default), lzma, zstd, and none are unaffected.
- The image ships one TimescaleDB version per major. A database created on an older TimescaleDB must run
  `ALTER EXTENSION timescaledb UPDATE` in a fresh session before use.

### Ports

| Port   | Description                             |
| ------ | --------------------------------------- |
| `5432` | PostgreSQL                              |
| `8008` | Patroni REST API (readiness, role, DCS) |
| `8080` | bg_mon metrics (JSON)                   |

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
  cryptographic operations.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the postgres user. Ensure that necessary files and directories are accessible to the postgres user.                                                                                                                                                                 |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |
| Tag scheme         | Tags are qualified by the primary PostgreSQL major through the `pg17` flavor suffix (for example `4.1-pg17`). The image still bundles PostgreSQL 14 through 17 for in-place upgrades.                                                                                                                                        |
| PGDATA path        | `PGDATA` is `/home/postgres/pgdata/pgroot/data`. Mount persistent volumes at `/home/postgres/pgdata`, owned by uid 70.                                                                                                                                                                                                       |

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
