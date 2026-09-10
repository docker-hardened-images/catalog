## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/percona-server-mongodb:<tag>`
- Mirrored image: `<your-namespace>/dhi-percona-server-mongodb:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Replace `<tag>` with the tag you want to run, for example `7.0`.

## Start a Percona Server for MongoDB image

### Basic usage

The entrypoint is `/usr/local/bin/mongod` (a symlink to `/usr/bin/mongod`), so any arguments you pass are `mongod`
flags. The server binds to the loopback interface only unless you tell it otherwise:

```bash
$ docker run -d --name psmdb -p 127.0.0.1:27017:27017 \
  dhi.io/percona-server-mongodb:<tag> --bind_ip_all
```

The loopback host binding keeps the unauthenticated server off your network interfaces. Connect with `mongosh` from the
same container:

```bash
$ docker exec psmdb mongosh --quiet --eval 'db.runCommand({ping: 1})'
```

### With Docker Compose (recommended for complex setups)

```yaml
services:
  psmdb:
    image: dhi.io/percona-server-mongodb:<tag>
    container_name: psmdb
    command: ["--bind_ip_all"]
    ports:
      - "127.0.0.1:27017:27017"
    volumes:
      - psmdb-data:/data/db

volumes:
  psmdb-data:
```

### Environment variables

The runtime image starts `mongod` directly and reads no environment variables. The `-compat` flavor ships the upstream
entrypoint script (`/entrypoint.sh`, a symlink to `/usr/local/bin/docker-entrypoint.sh`) and honours these variables:

| Variable                          | Description                                                           | Default | Required |
| --------------------------------- | --------------------------------------------------------------------- | ------- | -------- |
| `MONGO_INITDB_ROOT_USERNAME`      | Root user created on first start; enables `--auth`                    | (unset) | No       |
| `MONGO_INITDB_ROOT_PASSWORD`      | Password for the root user; both variables must be set together       | (unset) | No       |
| `MONGO_INITDB_ROOT_USERNAME_FILE` | Read the root user name from a file (Docker secrets)                  | (unset) | No       |
| `MONGO_INITDB_ROOT_PASSWORD_FILE` | Read the root password from a file (Docker secrets)                   | (unset) | No       |
| `MONGO_INITDB_DATABASE`           | Database used when running `/docker-entrypoint-initdb.d/*.js` scripts | `test`  | No       |
| `PERCONA_TELEMETRY_DISABLE`       | Set to `0` to enable the server's built-in Percona telemetry          | `1`     | No       |

```bash
$ docker run -d --name psmdb -p 127.0.0.1:27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=change-me \
  dhi.io/percona-server-mongodb:<tag>-compat
```

## Common Percona Server for MongoDB use cases

### Persistent data

`mongod` stores data in `/data/db`, which is owned by the runtime user (uid 1001, mode `0770`). Mount a volume there:

```bash
$ docker run -d --name psmdb -p 127.0.0.1:27017:27017 \
  -v psmdb-data:/data/db \
  dhi.io/percona-server-mongodb:<tag> --bind_ip_all
```

When mounting a host directory instead of a named volume, make it writable by uid 1001. On Kubernetes, set `fsGroup` on
the pod so the platform makes the volume writable for the container user.

### Data-at-rest encryption

Percona Server for MongoDB encrypts WiredTiger data files with a key you provide. Generate a 32-byte key, mount it
read-only with mode `0400`, and start the server with encryption enabled:

```bash
$ openssl rand -base64 32 > mongodb-keyfile
$ chmod 0400 mongodb-keyfile
$ sudo chown 1001 mongodb-keyfile
$ docker run -d --name psmdb -p 127.0.0.1:27017:27017 \
  -v psmdb-data:/data/db \
  -v "$(pwd)/mongodb-keyfile:/data/configdb/mongodb-keyfile:ro" \
  dhi.io/percona-server-mongodb:<tag> \
  --bind_ip_all --enableEncryption --encryptionKeyFile /data/configdb/mongodb-keyfile
```

The key file must be owned by uid 1001 with mode `0400`. When it has to stay owned by another user, `mongod` accepts a
group-readable `0440` file together with `--relaxPermChecks`. Use `perconadecrypt` from the same image to decrypt data
files offline with the same key. For Vault, KMIP and OpenBao key management see the
[upstream documentation](https://docs.percona.com/percona-server-for-mongodb/7.0/data-at-rest-encryption.html).

### Backup and restore with the database tools

The image ships the MongoDB database tools. Dump and restore a database inside the running container:

```bash
$ docker exec psmdb mongosh --quiet --eval 'db.docs.insertOne({name: "example"})' app
$ docker exec psmdb mongodump --db app --out /tmp/dump
$ docker exec psmdb mongorestore --drop /tmp/dump
```

### Replica set with key file authentication

Members of a replica set authenticate each other with a shared key file, which also enables client authentication. Start
two members on one network, initiate the set from the first member with a higher election priority so it becomes
primary, and create the first administrative user over its local connection (the localhost exception allows it before
any user exists):

```bash
$ openssl rand -base64 756 > rs-keyfile
$ chmod 0400 rs-keyfile
$ sudo chown 1001 rs-keyfile
$ docker network create psmdb-net
$ for m in rs0-a rs0-b; do
    docker run -d --name "$m" --network psmdb-net \
      -v "$(pwd)/rs-keyfile:/data/configdb/keyfile:ro" \
      dhi.io/percona-server-mongodb:<tag> --replSet rs0 --keyFile /data/configdb/keyfile --bind_ip_all
  done
$ docker exec rs0-a mongosh --quiet --eval \
  'rs.initiate({_id: "rs0", members: [{_id: 0, host: "rs0-a:27017", priority: 2}, {_id: 1, host: "rs0-b:27017"}]})'
$ docker exec rs0-a mongosh --quiet --eval \
  'while (!db.hello().isWritablePrimary) sleep(500); db.getSiblingDB("admin").createUser({user: "admin", pwd: "change-me", roles: ["root"]})'
```

### Sharded cluster router

Run the same image as a `mongos` query router by overriding the entrypoint. This example starts a single-member config
server replica set and a router in front of it:

```bash
$ docker network create psmdb-net
$ docker run -d --name cfgsvr --network psmdb-net \
  dhi.io/percona-server-mongodb:<tag> --configsvr --replSet cfg --bind_ip_all --port 27017
$ docker exec cfgsvr mongosh --quiet --eval \
  'rs.initiate({_id: "cfg", configsvr: true, members: [{_id: 0, host: "cfgsvr:27017"}]})'
$ docker run -d --name mongos --network psmdb-net -p 127.0.0.1:27017:27017 \
  --entrypoint mongos dhi.io/percona-server-mongodb:<tag> --configdb cfg/cfgsvr:27017 --bind_ip_all
```

### FIPS mode with TLS

The `-fips` variants ship the OpenSSL FIPS provider. Start `mongod` with TLS and `--tlsFIPSMode` so that only
FIPS-approved algorithms are used:

```bash
$ docker run -d --name psmdb -p 127.0.0.1:27017:27017 \
  -v "$(pwd)/tls.pem:/data/configdb/tls.pem:ro" \
  -v "$(pwd)/ca.pem:/data/configdb/ca.pem:ro" \
  dhi.io/percona-server-mongodb:<tag>-fips \
  --bind_ip_all --tlsMode requireTLS --tlsCertificateKeyFile /data/configdb/tls.pem \
  --tlsCAFile /data/configdb/ca.pem --tlsAllowConnectionsWithoutCertificates --tlsFIPSMode
```

`tls.pem` holds the server private key followed by its certificate, and `--tlsCAFile` names the chain of trust the
server requires. Drop `--tlsAllowConnectionsWithoutCertificates` to require client certificates signed by that CA. The
server logs `FIPS 140 mode activated` on start.

FIPS scope: `mongod`, `mongos` and `mongosh` perform their TLS and cryptographic operations through the OpenSSL FIPS
provider in the `-fips` variants (`mongosh` links the system OpenSSL and reports `crypto.getFips() == 1` there). The
database tools (`mongodump`, `mongorestore`, `mongoexport`, `mongoimport`, `mongostat`, `mongotop`, `mongofiles`,
`bsondump`) are Go programs that use Go's own cryptography and are not covered by the FIPS claim.

### Percona Operator for MongoDB

The Percona Operator for MongoDB runs the database container with its own entrypoint script, which needs `bash`,
`coreutils`, `findutils`, `gosu`, `jq`, `mawk`, `numactl` and `procps` alongside the database binaries. Use the
`-compat` flavor for operator-managed clusters and set `image` in the `PerconaServerMongoDB` custom resource to
`dhi.io/percona-server-mongodb:<tag>-compat`. On Kubernetes the operator defaults to `runAsUser: 1001` and
`fsGroup: 1001`, which match the image user; on OpenShift it leaves the security context to the platform and mounts the
data volume with `fsGroup`.

## Non-hardened images vs. Docker Hardened Images

- The runtime image starts `/usr/local/bin/mongod` directly (`/usr/bin/mongod` stays in place). The upstream image
  starts a bash entrypoint script that handles `MONGO_INITDB_*` bootstrapping, `/docker-entrypoint-initdb.d` scripts,
  `--config` rewriting, TLS flag translation and the `numactl --interleave=all` wrapper. That script ships in the
  `-compat` flavor as `/usr/local/bin/docker-entrypoint.sh`, reachable at the upstream path `/entrypoint.sh`, together
  with `bash`, `coreutils`, `findutils`, `gosu`, `grep`, `jq`, `mawk`, `numactl`, `procps` and `mongobridge`. Starting
  the `-compat` flavor as root drops to the image user through `gosu`, as upstream does.
- `/data/db`, `/data/configdb` and `/var/log/mongo` are owned by uid 1001 and gid 1001 with mode `0770`. The upstream
  image keeps them group-writable by gid 0 so that arbitrary uids in the root group can write; here an arbitrary uid
  relies on `fsGroup` on the volume, or on the `-compat` entrypoint fixing up `/data/db` and `/data/configdb` ownership
  when the container starts as root.
- Percona's telemetry agent and its `call-home.sh` script are not included. The `-compat` entrypoint disables the
  server's built-in telemetry unless `PERCONA_TELEMETRY_DISABLE=0` is set; the runtime image leaves the `mongod` default
  in place, which you can change with `--setParameter perconaTelemetry=false`.
- The host-service helper scripts `percona-server-mongodb-helper.sh` and `percona-server-mongodb-enable-auth.sh` are not
  included; they target systemd installations.
- `mongosh` is the upstream MongoDB Shell release rather than Percona's rebuilt package of the same version.

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

- Compat variants support more seamless usage of DHI as a drop-in replacement for upstream images, particularly for
  circumstances that the ultra-minimal runtime variant may not fully support. These images typically:

  - Run as the nonroot user
  - Improve compatibility with upstream helm charts
  - Include optional tools that are critical for certain use-cases

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
