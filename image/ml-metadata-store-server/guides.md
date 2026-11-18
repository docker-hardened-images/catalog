## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/ml-metadata-store-server:<tag>`
- Mirrored image: `<your-namespace>/dhi-ml-metadata-store-server:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This guide covers running the ML Metadata (MLMD) gRPC server in a container. For the MLMD data model, client libraries,
and the complete list of server options, see the upstream project at https://github.com/google/ml-metadata.

## Start an ML Metadata Store Server image

Run the following command and replace `<tag>` with the image variant you want to run. The server listens for gRPC
requests on port 8080.

```bash
$ docker run -d --name mlmd -p 8080:8080 dhi.io/ml-metadata-store-server:<tag>
```

Without a database connection the server uses an in-memory database, so all metadata is lost when the container stops.
Use this mode only for trying out the API. The logs confirm the server is ready:

```bash
$ docker logs mlmd
WARNING: Logging before InitGoogleLogging() is written to STDERR
W1115 07:52:30.474781     1 metadata_store_server_main.cc:405] The connection_config is not given. Using in memory fake database, any metadata will not be persistent
I1115 07:52:30.490036     1 metadata_store_server_main.cc:577] Server listening on 0.0.0.0:8080
```

The server has no HTTP endpoint. To call the gRPC API from the command line, see
[Call the gRPC API with grpcurl](#call-the-grpc-api-with-grpcurl).

### Environment variables

| Variable                            | Description                                                                                          | Default | Required |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------- | ------- | -------- |
| `GRPC_PORT`                         | Port the gRPC server listens on inside the container.                                                | `8080`  | No       |
| `METADATA_STORE_SERVER_CONFIG_FILE` | Path to a `MetadataStoreServerConfig` text-format file that defines the database connection and TLS. | unset   | No       |

### Server flags

Any arguments you add after the image name are passed to `metadata_store_server` as command-line flags. This is how you
connect the server to MySQL or PostgreSQL in the examples below. A flag you pass this way takes precedence over the
environment variables above; for example, `--grpc_port=9090` overrides `GRPC_PORT`.

## Common ML Metadata Store Server use cases

The examples below name the server container `mlmd`. Remove the `mlmd` container from a previous example before you
start the next one. The grpcurl and TLS examples connect to the MySQL server from
[Store metadata in MySQL](#store-metadata-in-mysql), so keep that MySQL container running.

### Store metadata in MySQL

MySQL is the backend that Kubeflow Pipelines uses. Create a network, then start MySQL on it:

```bash
$ docker network create mlmd-net
$ docker run -d --name mysql --network mlmd-net \
  -e MYSQL_ROOT_PASSWORD=my-secret-pw \
  dhi.io/mysql:<tag> mysqld
```

Wait until `docker logs mysql` reports `ready for connections`, because the server exits at startup if it can't reach
its database. Then start the server and point it at MySQL:

```bash
$ docker run -d --name mlmd --network mlmd-net -p 8080:8080 \
  dhi.io/ml-metadata-store-server:<tag> \
  --mysql_config_host=mysql \
  --mysql_config_port=3306 \
  --mysql_config_database=metadb \
  --mysql_config_user=root \
  --mysql_config_password=my-secret-pw
```

On first start, the server creates the `metadb` database and the MLMD schema. When you upgrade from an earlier MLMD
release against an existing database, add `--enable_database_upgrade=true` so the server migrates the schema. For
production, create a dedicated MySQL user for MLMD instead of using `root`.

### Store metadata in PostgreSQL

Select the PostgreSQL backend with `--metadata_source_config_type=postgresql` and the `--postgres_config_*` flags:

```bash
$ docker network create mlmd-net
$ docker run -d --name postgres --network mlmd-net \
  -e POSTGRES_PASSWORD=mysecretpassword \
  dhi.io/postgres:<tag>
```

When `docker logs postgres` reports `database system is ready to accept connections`, start the server:

```bash
$ docker run -d --name mlmd --network mlmd-net -p 8080:8080 \
  dhi.io/ml-metadata-store-server:<tag> \
  --metadata_source_config_type=postgresql \
  --postgres_config_host=postgres \
  --postgres_config_port=5432 \
  --postgres_config_user=postgres \
  --postgres_config_password=mysecretpassword \
  --postgres_config_dbname=metadb
```

The server creates the `metadb` database and schema on first start.

### Persist metadata in SQLite

For a single-node setup without a separate database server, store metadata in a SQLite file. SQLite is configured
through a config file rather than flags. Create `mlmd-config.pbtxt`:

```text
connection_config {
  sqlite {
    filename_uri: "/data/metadata.db"
    connection_mode: READWRITE_OPENCREATE
  }
}
```

The server runs as the nonroot user (UID 65532), so the directory that holds the database file must be writable by that
user. Docker creates new volumes owned by root, so change the owner before you start the server:

```bash
$ docker volume create mlmd_data
$ docker run --rm -v mlmd_data:/data --user 0 dhi.io/busybox:1 chown 65532:65532 /data
$ docker run -d --name mlmd -p 8080:8080 \
  -v mlmd_data:/data \
  -v "$PWD/mlmd-config.pbtxt:/etc/mlmd/config.pbtxt:ro" \
  -e METADATA_STORE_SERVER_CONFIG_FILE=/etc/mlmd/config.pbtxt \
  dhi.io/ml-metadata-store-server:<tag>
```

Metadata now survives container restarts and re-creation. If the directory isn't writable, the server exits with
`Cannot connect sqlite3 database: unable to open database file`.

### Call the gRPC API with grpcurl

The server doesn't enable gRPC reflection, so clients need the MLMD protocol definitions. Download them from the
upstream release that matches the server version:

```bash
$ mkdir -p ml_metadata/proto
$ for f in metadata_store.proto metadata_store_service.proto; do
    curl -sSfL -o "ml_metadata/proto/$f" \
      "https://raw.githubusercontent.com/google/ml-metadata/v1.21.0/ml_metadata/proto/$f"
  done
```

With the server from [Store metadata in MySQL](#store-metadata-in-mysql) running on the `mlmd-net` network, register an
artifact type and then list the registered types:

```bash
$ docker run --rm --network mlmd-net -v "$PWD:/protos:ro" fullstorydev/grpcurl:v1.9.3 \
  -plaintext -import-path /protos -proto ml_metadata/proto/metadata_store_service.proto \
  -d '{"artifact_type": {"name": "DataSet", "properties": {"split": "STRING"}}}' \
  mlmd:8080 ml_metadata.MetadataStoreService/PutArtifactType
{
  "typeId": "10"
}
$ docker run --rm --network mlmd-net -v "$PWD:/protos:ro" fullstorydev/grpcurl:v1.9.3 \
  -plaintext -import-path /protos -proto ml_metadata/proto/metadata_store_service.proto \
  -d '{}' mlmd:8080 ml_metadata.MetadataStoreService/GetArtifactTypes
{
  "artifactTypes": [
    {
      "id": "10",
      "name": "DataSet",
      "properties": {
        "split": "STRING"
      }
    }
  ]
}
```

Applications usually connect through the MLMD Python client (`pip install ml-metadata`) with a
`MetadataStoreClientConfig` that points at the server's host and port.

### Secure the gRPC API with TLS

To serve gRPC over TLS, add an `ssl_config` block to the config file. The block holds the PEM contents of the key and
certificate, not file paths, and a config file must also define the database connection. The following commands create a
self-signed certificate for the hostname `mlmd` and write a config file that connects to the MySQL server from
[Store metadata in MySQL](#store-metadata-in-mysql):

```bash
$ openssl req -x509 -newkey rsa:3072 -sha256 -days 365 -nodes \
  -keyout server.key -out server.crt -subj "/CN=mlmd" \
  -addext "subjectAltName=DNS:mlmd,DNS:localhost"
$ cat > mlmd-config.pbtxt <<EOF
connection_config {
  mysql {
    host: "mysql"
    port: 3306
    database: "metadb"
    user: "root"
    password: "my-secret-pw"
  }
}
ssl_config {
  server_key: "$(awk '{printf "%s\\n", $0}' server.key)"
  server_cert: "$(awk '{printf "%s\\n", $0}' server.crt)"
  client_verify: false
}
EOF
```

The config file contains the private key, so protect it accordingly. It must still be readable by UID 65532 inside the
container. Start the server with the config file:

```bash
$ docker run -d --name mlmd --network mlmd-net -p 8080:8080 \
  -v "$PWD/mlmd-config.pbtxt:/etc/mlmd/config.pbtxt:ro" \
  -e METADATA_STORE_SERVER_CONFIG_FILE=/etc/mlmd/config.pbtxt \
  dhi.io/ml-metadata-store-server:<tag>
```

Clients must now connect over TLS and trust the certificate. With the protocol definitions from
[Call the gRPC API with grpcurl](#call-the-grpc-api-with-grpcurl) in the current directory:

```bash
$ docker run --rm --network mlmd-net -v "$PWD:/protos:ro" fullstorydev/grpcurl:v1.9.3 \
  -cacert /protos/server.crt -import-path /protos \
  -proto ml_metadata/proto/metadata_store_service.proto \
  -d '{}' mlmd:8080 ml_metadata.MetadataStoreService/GetArtifactTypes
```

Set `client_verify: true` and `custom_ca` to require client certificates (mutual TLS). In FIPS variants, gRPC TLS and
database client TLS use the OpenSSL FIPS provider.

### Use with Kubeflow Pipelines

Kubeflow Pipelines runs MLMD as its `metadata-grpc-deployment`. That deployment overrides the container command with
`/bin/metadata_store_server` and passes `--mysql_config_*` flags. This image provides `/bin/metadata_store_server` in
every variant, so you can replace the image in that deployment without changing its command or arguments. The server
needs no writable paths when it uses MySQL, so the image's nonroot user (UID 65532) works without extra volumes.

The equivalent `docker run` command:

```bash
$ docker run -d --name mlmd --network mlmd-net -p 8080:8080 \
  --entrypoint /bin/metadata_store_server \
  dhi.io/ml-metadata-store-server:<tag> \
  --grpc_port=8080 \
  --mysql_config_database=metadb \
  --mysql_config_host=mysql \
  --mysql_config_port=3306 \
  --mysql_config_user=root \
  --mysql_config_password=my-secret-pw \
  --enable_database_upgrade=true
```

## Non-hardened images vs. Docker Hardened Images

| Feature             | Upstream `ml_metadata_store_server` image | Docker Hardened ML Metadata Store Server                          |
| ------------------- | ----------------------------------------- | ----------------------------------------------------------------- |
| Base image          | Ubuntu 20.04                              | Debian 13 or Alpine 3.24                                          |
| User                | `root`                                    | Nonroot (UID 65532) in runtime variants; `root` in `dev` variants |
| Shell               | Full Ubuntu userland                      | `/bin/sh` for the entrypoint: `dash` on Debian, BusyBox on Alpine |
| Package manager     | `apt`                                     | None in runtime variants; `apt` or `apk` in `dev` variants        |
| Container arguments | Ignored                                   | Appended to the server command line as flags                      |
| Server process      | Runs as a child of `/bin/sh`              | Runs as PID 1                                                     |
| MLMD source tree    | Included at `/mlmd-src`                   | Not included                                                      |
| FIPS                | Not available                             | FIPS variants use the OpenSSL FIPS provider                       |

Notes for migration:

- **Writable paths.** Upstream runs as root, so a SQLite database can live anywhere in the container. In this image,
  mount a volume that UID 65532 can write to and point `filename_uri` at it, as shown in
  [Persist metadata in SQLite](#persist-metadata-in-sqlite). MySQL and PostgreSQL setups need no writable paths.
- **Passing flags.** Upstream ignores container arguments, so existing deployments override the command to pass flags.
  Those overrides keep working because `/bin/metadata_store_server` exists in this image. You can also drop the override
  and pass flags as container arguments.
- **Stopping the container.** The server doesn't handle `SIGTERM`, so `docker stop` waits for the stop timeout (10
  seconds by default) before it kills the server. This matches upstream. For a fast shutdown, run the container with
  `docker run --init`, or use your orchestrator's init process.

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
