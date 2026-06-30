## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This Docker Hardened Patroni image bundles the Patroni daemon and a complete PostgreSQL server in a single container so
that each cluster member runs both as one unit. Tags follow the format `<patroni-version>-pg<postgres-major>`, for
example `4.1.3-pg18`, or the major-version tag `4-pg18`, which points to the latest Patroni 4.x release for that
PostgreSQL major.

The image does not ship a Patroni configuration of its own. Provide one at runtime either by mounting a YAML config file
(Patroni reads its first positional argument as a config path) or by setting `PATRONI_*` environment variables
documented at https://patroni.readthedocs.io.

### What's included in this Patroni image

This Docker Hardened Patroni image includes:

- `patroni` — the HA daemon that supervises PostgreSQL and coordinates failover via the configured DCS
- `patronictl` — the operator CLI for listing members, triggering failover/switchover, reloading, and restarting
- A bundled PostgreSQL server matching the `pg<major>` tag (binaries on `PATH` at `/opt/postgresql/<major>/bin`)
- Python dependencies for the most common deployments: `etcd3`, `kubernetes`, and `psycopg3`

All of Patroni's console scripts are on `PATH`, including `patroni_wale_restore` and `patroni_barman`. The scripts whose
optional dependencies ship outside the bundled extras still run only after you add those deps: `patroni_aws` needs the
`aws` extra (`boto3`) and `patroni_raft_controller` needs the `raft` extra (`pysyncobj`). Likewise the Consul,
ZooKeeper, and Raft DCS backends are not bundled. Layer a derived image that runs `pip install patroni[<extras>]` from
the dev variant if you need any of these.

## Start a Patroni cluster member

Patroni cannot run standalone — it needs a DCS (etcd, Consul, ZooKeeper, or Kubernetes) reachable on the network. The
example below uses etcd and configures Patroni via a mounted YAML file. Individual settings can still be overridden by
the `PATRONI_*` environment variables documented under "Environment variables" below.

### Basic usage with etcd

Patroni's env-var loader does not populate the `bootstrap` section, so a fresh single-node cluster cannot `initdb` from
`PATRONI_*` variables alone. The basic example therefore mounts a small YAML config that defines the bootstrap step;
individual values can still be overridden by `PATRONI_*` env vars in production.

Save the following as `patroni.yml` in the current directory:

```yaml
scope: demo
namespace: /service/
name: patroni1

etcd3:
  hosts: patroni-etcd:2379

restapi:
  listen: 0.0.0.0:8008
  connect_address: patroni1:8008

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host replication replicator 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5

postgresql:
  listen: 0.0.0.0:5432
  connect_address: patroni1:5432
  data_dir: /var/lib/postgresql/18/data
  authentication:
    superuser:
      username: postgres
      password: mysecretpassword
    replication:
      username: replicator
      password: replicatorpassword
```

Then bring up etcd and the first cluster member:

```bash
# Create the shared network the cluster members and DCS will live on
docker network create patroni-net

# Start a single-node etcd for the demo (use a real cluster in production)
docker run --rm -d --name patroni-etcd --network patroni-net \
  -e ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379 \
  -e ETCD_ADVERTISE_CLIENT_URLS=http://patroni-etcd:2379 \
  -e ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380 \
  -e ETCD_INITIAL_ADVERTISE_PEER_URLS=http://patroni-etcd:2380 \
  -e ETCD_INITIAL_CLUSTER=default=http://patroni-etcd:2380 \
  quay.io/coreos/etcd:v3.5.13

# Start the first Patroni member with the config above
docker run --rm -d --name patroni1 --network patroni-net \
  -v "$(pwd)/patroni.yml:/etc/patroni/patroni.yml:ro" \
  -p 8008:8008 -p 5432:5432 \
  dhi.io/patroni:<tag> /etc/patroni/patroni.yml
```

### Inspecting cluster state

Once a cluster member is up, `patronictl` reports its view of the world:

```bash
docker exec -it patroni1 patronictl -c /etc/patroni/patroni.yml list demo
```

### Environment variables

Patroni's full set of environment variables is documented at https://patroni.readthedocs.io/en/latest/ENVIRONMENT.html.
The handful below are the minimum needed to run a member.

| Variable                             | Description                                                      | Default                            | Required   |
| ------------------------------------ | ---------------------------------------------------------------- | ---------------------------------- | ---------- |
| `PATRONI_NAME`                       | Unique name for this cluster member.                             | _(hostname)_                       | Yes        |
| `PATRONI_SCOPE`                      | Cluster name; all members of one cluster share the same scope.   | _(unset)_                          | Yes        |
| `PATRONI_ETCD3_HOSTS`                | Comma-separated `host:port` list of the etcd v3 endpoints.       | _(unset)_                          | Yes (etcd) |
| `PATRONI_RESTAPI_LISTEN`             | `host:port` Patroni's REST API binds to.                         | _(unset)_                          | Yes        |
| `PATRONI_RESTAPI_CONNECT_ADDRESS`    | `host:port` other members use to reach this member's REST API.   | _(unset)_                          | Yes        |
| `PATRONI_POSTGRESQL_LISTEN`          | `host:port` PostgreSQL listens on.                               | _(unset)_                          | Yes        |
| `PATRONI_POSTGRESQL_CONNECT_ADDRESS` | `host:port` other members use to reach this member's PostgreSQL. | _(unset)_                          | Yes        |
| `PATRONI_SUPERUSER_USERNAME`         | PostgreSQL superuser created at `initdb` time.                   | _(unset)_                          | Yes        |
| `PATRONI_SUPERUSER_PASSWORD`         | Password for the superuser.                                      | _(unset)_                          | Yes        |
| `PATRONI_REPLICATION_USERNAME`       | Role used by standby members for streaming replication.          | _(unset)_                          | Yes        |
| `PATRONI_REPLICATION_PASSWORD`       | Password for the replication role.                               | _(unset)_                          | Yes        |
| `PGDATA`                             | PostgreSQL data directory inside the container.                  | `/var/lib/postgresql/<MAJOR>/data` | No         |

## Common Patroni use cases

### Persistent data

Patroni's PostgreSQL data lives under `/var/lib/postgresql/<MAJOR>/data` by default. Mount a volume at the parent
directory so the versioned subdirectory is managed by the image:

```bash
docker volume create patroni1-data
docker run -d --name patroni1 \
  -v patroni1-data:/var/lib/postgresql \
  -e PATRONI_NAME=patroni1 \
  ... \
  dhi.io/patroni:<tag>
```

### Docker Compose: three-node cluster with etcd

All three members share the same `patroni.yml` (cluster scope, DCS endpoint, `bootstrap:` block, authentication).
Per-node identity (`name`, `connect_address`) is supplied via `PATRONI_*` env vars, which patroni overlays on top of the
YAML at startup. Save the following as `patroni.yml` in the same directory as the compose file:

```yaml
scope: demo
namespace: /service/

etcd3:
  hosts: etcd:2379

restapi:
  listen: 0.0.0.0:8008

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host replication replicator 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5

postgresql:
  listen: 0.0.0.0:5432
  data_dir: /var/lib/postgresql/18/data
  authentication:
    superuser:
      username: postgres
      password: mysecretpassword
    replication:
      username: replicator
      password: replicatorpassword
```

Then bring the cluster up:

```yaml
services:
  etcd:
    image: quay.io/coreos/etcd:v3.5.13
    environment:
      ETCD_LISTEN_CLIENT_URLS: http://0.0.0.0:2379
      ETCD_ADVERTISE_CLIENT_URLS: http://etcd:2379
      ETCD_LISTEN_PEER_URLS: http://0.0.0.0:2380
      ETCD_INITIAL_ADVERTISE_PEER_URLS: http://etcd:2380
      ETCD_INITIAL_CLUSTER: default=http://etcd:2380

  patroni1: &patroni
    image: dhi.io/patroni:4-pg18
    depends_on: [etcd]
    command: /etc/patroni/patroni.yml
    environment:
      PATRONI_NAME: patroni1
      PATRONI_RESTAPI_CONNECT_ADDRESS: patroni1:8008
      PATRONI_POSTGRESQL_CONNECT_ADDRESS: patroni1:5432
    volumes:
      - ./patroni.yml:/etc/patroni/patroni.yml:ro
      - patroni1-data:/var/lib/postgresql

  patroni2:
    <<: *patroni
    environment:
      PATRONI_NAME: patroni2
      PATRONI_RESTAPI_CONNECT_ADDRESS: patroni2:8008
      PATRONI_POSTGRESQL_CONNECT_ADDRESS: patroni2:5432
    volumes:
      - ./patroni.yml:/etc/patroni/patroni.yml:ro
      - patroni2-data:/var/lib/postgresql

  patroni3:
    <<: *patroni
    environment:
      PATRONI_NAME: patroni3
      PATRONI_RESTAPI_CONNECT_ADDRESS: patroni3:8008
      PATRONI_POSTGRESQL_CONNECT_ADDRESS: patroni3:5432
    volumes:
      - ./patroni.yml:/etc/patroni/patroni.yml:ro
      - patroni3-data:/var/lib/postgresql

volumes:
  patroni1-data:
  patroni2-data:
  patroni3-data:
```

### Triggering a manual switchover

```bash
docker exec -it patroni1 patronictl -c /etc/patroni/patroni.yml switchover demo --leader patroni1 --candidate patroni2 --force
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
the host.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
