## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/keydb:<tag>`
- Mirrored image: `<your-namespace>/dhi-keydb:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Replace `<tag>` with the tag you want to run, for example `6.3`.

### What's included in this KeyDB image

This Docker Hardened Image ships the complete KeyDB toolkit, built with TLS and FLASH storage support:

- `keydb-server`: The KeyDB server
- `keydb-cli`: KeyDB command-line interface (`redis-cli` is a compatibility alias)
- `keydb-sentinel`: KeyDB Sentinel for high availability
- `keydb-benchmark`: Performance testing tool
- `keydb-check-aof`: AOF file checker and repairer
- `keydb-check-rdb`: RDB file checker
- `keydb-diagnostic-tool`: Server latency and throughput diagnostics

The binaries live in `/usr/bin` and are also reachable at `/usr/local/bin`, where the upstream image installs them. The
server starts from `/etc/keydb/keydb.conf` (also available as `/etc/keydb/redis.conf`), which includes
`/etc/keydb/conf.d/local.conf`. The bundled `/etc/keydb/conf.d/local.conf` applies the same container defaults as the
upstream image: listen on all interfaces, protected mode off, data directory `/data`. Mount a custom configuration as a
single file over `/etc/keydb/keydb.conf`; a directory mounted over `/etc/keydb` must also carry `conf.d/local.conf`,
because the shipped configuration includes it.

## Start a KeyDB instance

```console
$ docker run --name some-keydb -d -p 127.0.0.1:6379:6379 dhi.io/keydb:<tag>
```

The server listens on port 6379 with protected mode disabled, exactly like the upstream `eqalpha/keydb` image. The
loopback host binding above keeps the unauthenticated server off your network interfaces; use `--requirepass` or a
mounted configuration before exposing it more widely.

Connect with the bundled CLI:

```console
$ docker exec -it some-keydb keydb-cli ping
PONG
```

The runtime image has no shell, so `KEYDB_PASSWORD` and the upstream flag shorthand (`docker run ... --port 6380`) are
not interpreted; pass `--requirepass` and other options as arguments after the configuration file, or use the `compat`
flavor described below. Health checks must use the exec form, for example in Compose:

```yaml
healthcheck:
  test: ["CMD", "keydb-cli", "ping"]
  interval: 10s
```

## Common KeyDB use cases

### Persistence

Mount a volume at `/data` (the working directory and RDB/AOF location) and enable the append-only file:

```console
$ docker run --name keydb-persistent -d -p 127.0.0.1:6379:6379 \
  -v keydb-data:/data \
  dhi.io/keydb:<tag> keydb-server /etc/keydb/keydb.conf --appendonly yes
```

The runtime image runs as uid 65532 and `/data` is mode `0770`. A bind-mounted host directory must be writable by that
uid, otherwise the server cannot write `dump.rdb` or `appendonly.aof`. Volumes created by `eqalpha/keydb` are owned by
its `keydb` user (uid 999): either `chown -R 65532:65532` the volume once, or start the `compat` flavor once with
`--user 0`, whose entrypoint re-owns `/data` before stepping down. Under an arbitrary uid (for example an OpenShift
restricted SCC), grant the volume to the pod's `fsGroup` or run with `--group-add 65532`.

### Multithreading

KeyDB runs its event loop on several threads. Set the thread count on the command line or in your configuration:

```console
$ docker run --name keydb-mt -d -p 127.0.0.1:6379:6379 \
  dhi.io/keydb:<tag> keydb-server /etc/keydb/keydb.conf --server-threads 4
```

### Active replication

Two nodes that replicate each other accept writes on both sides:

```console
$ docker network create keydb-net
$ docker run --name keydb-a -d --network keydb-net dhi.io/keydb:<tag> \
  keydb-server /etc/keydb/keydb.conf --active-replica yes --replicaof keydb-b 6379
$ docker run --name keydb-b -d --network keydb-net dhi.io/keydb:<tag> \
  keydb-server /etc/keydb/keydb.conf --active-replica yes --replicaof keydb-a 6379
$ docker exec keydb-a keydb-cli set written-on-a 1
$ docker exec keydb-b keydb-cli get written-on-a
1
```

Multi-master topologies and cluster mode are described in the
[KeyDB active replication documentation](https://docs.keydb.dev/docs/active-rep/).

### FLASH storage

The server is built with `ENABLE_FLASH=yes`. Point the storage provider at the `/flash` directory (owned by the runtime
user) to keep the working set in memory and the full dataset on disk:

```console
$ docker run --name keydb-flash -d -p 127.0.0.1:6379:6379 \
  -v keydb-flash:/flash \
  dhi.io/keydb:<tag> keydb-server /etc/keydb/keydb.conf --storage-provider flash /flash
```

Upstream labels FLASH as experimental (beta); sizing and tuning options are described in the
[FLASH documentation](https://docs.keydb.dev/docs/flash/).

### TLS

Mount your certificates so they are readable by uid 65532 and start the server on a TLS port:

```console
$ docker run --name keydb-tls -d -p 127.0.0.1:6379:6379 \
  -v /path/to/tls:/tls:ro \
  dhi.io/keydb:<tag> keydb-server /etc/keydb/keydb.conf \
  --port 0 --tls-port 6379 \
  --tls-cert-file /tls/server.crt --tls-key-file /tls/server.key --tls-ca-cert-file /tls/ca.crt
$ docker exec keydb-tls keydb-cli --tls \
  --cert /tls/server.crt --key /tls/server.key --cacert /tls/ca.crt ping
PONG
```

### Sentinel

Sentinel rewrites its configuration file through a temporary file in the same directory. The bundled
`/etc/keydb/sentinel.conf` is root-owned and serves as a template only: copy it into a directory writable by uid 65532,
make the copy writable by uid 65532 as well, replace the default `sentinel monitor mymaster 127.0.0.1 6379 2` line with
your own primary, and mount that directory. Naming the primary by hostname needs `sentinel resolve-hostnames yes` in the
file, and the name must resolve when Sentinel starts (primary already running on the same Docker network); otherwise
startup fails with `Can't resolve instance hostname.`:

```console
$ docker run --name keydb-sentinel -d -p 127.0.0.1:26379:26379 \
  -v /path/to/sentinel:/sentinel \
  dhi.io/keydb:<tag> keydb-sentinel /sentinel/sentinel.conf
```

### Performance testing

```console
$ docker run --name keydb-bench -d dhi.io/keydb:<tag>
$ docker exec keydb-bench keydb-benchmark -q -n 100000 -t set,get
```

## Non-hardened images vs. Docker Hardened Images

| Feature               | `eqalpha/keydb`                                             | `dhi.io/keydb`                                                                                                                                                                           |
| --------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User                  | Runs as root, steps down to `keydb` through `gosu`          | Runs as uid 65532; with `--user 0` only `compat` steps down, runtime and FIPS stay root                                                                                                  |
| Shell                 | Full shell                                                  | None in runtime and FIPS variants; `bash` in `compat` and `dev`                                                                                                                          |
| Entrypoint            | `docker-entrypoint.sh`                                      | Runtime and FIPS: `tini --`; `compat`: `tini -- /usr/local/bin/docker-entrypoint.sh`                                                                                                     |
| Command               | `keydb-server /etc/keydb/keydb.conf`                        | Same                                                                                                                                                                                     |
| Binary path           | `/usr/local/bin`                                            | `/usr/bin`, with `/usr/local/bin` symlinks                                                                                                                                               |
| Configuration         | `/etc/keydb/keydb.conf` edited in the Dockerfile            | Upstream `/etc/keydb/keydb.conf` plus `/etc/keydb/conf.d/local.conf` with the same overrides                                                                                             |
| `KEYDB_PASSWORD`      | Appended as `--requirepass` by the entrypoint script        | `compat` flavor only; the runtime image takes `--requirepass` as a command argument                                                                                                      |
| `/data`, `/flash`     | Owned by `keydb`, `/data` declared as a volume              | Owned by uid 65532, no volume declaration; mount your own                                                                                                                                |
| FLASH storage         | x86_64 image only                                           | amd64 and arm64                                                                                                                                                                          |
| `KEYDB_PRO_DIRECTORY` | Set to `/usr/local/bin/`                                    | Not set (unused since KeyDB 6.3 merged the Pro features)                                                                                                                                 |
| Message of the day    | `enable-motd yes`, fetches a banner from keydb.dev at start | `enable-motd no` in `local.conf`, nothing is fetched at start                                                                                                                            |
| `protected-mode`      | Compiled default flipped to `no`, config sets `no`          | Compiled default `yes` as in Redis; the shipped config sets `no`, a mounted config that omits it, or a start without a config file (`keydb-server --port 6380`), keeps protected mode on |
| Lua scripting         | Redis 6.2.6 sandbox                                         | Redis 6.2.7+ hardening backported: global and library tables are read-only (`Attempt to modify a readonly table`), `setfenv`/`getfenv`/`newproxy` need `lua-enable-deprecated-api yes`   |

The runtime image has no shell, so the upstream entrypoint conveniences (`docker run dhi.io/keydb:<tag> --port 6380` or
`KEYDB_PASSWORD`) live in the `compat` flavor, which adds `bash`, `coreutils`, `findutils`, `grep`, `gosu`, `hostname`,
`procps`, `sed` and an adapted copy of the upstream `docker-entrypoint.sh`. A flag-only start loads
`/etc/keydb/keydb.conf` first, so the container defaults above still apply:

```console
$ docker run --name keydb-compat -d -p 127.0.0.1:6379:6379 -e KEYDB_PASSWORD=change-me \
  dhi.io/keydb:<tag>-compat --appendonly yes
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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants. In this image the FIPS provider covers TLS
  (`tls-port`, replication and Sentinel connections); ACL and `requirepass` password hashing (SHA-256) and script
  hashing (SHA-1) use KeyDB's built-in implementations.

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
