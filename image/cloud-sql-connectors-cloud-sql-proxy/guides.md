## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/cloud-sql-connectors-cloud-sql-proxy:<tag>`
- Mirrored image: `<your-namespace>/dhi-cloud-sql-connectors-cloud-sql-proxy:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The Cloud SQL Auth Proxy is a sidecar. Your application connects to a local port, and the proxy opens the authenticated,
encrypted connection to Cloud SQL for MySQL, PostgreSQL, or SQL Server. The proxy does not serve a database. Full
upstream documentation is at https://github.com/GoogleCloudPlatform/cloud-sql-proxy and
https://cloud.google.com/sql/docs/mysql/connect-auth-proxy.

This image publishes two maintained lines. Pick the tag that matches the line you run today.

- Line 2 is the current proxy. It replaces `gcr.io/cloud-sql-connectors/cloud-sql-proxy`. The entrypoint is
  `/cloud-sql-proxy`.
- Line 1 is the v1 binary, and it is still maintained. It replaces `gcr.io/cloudsql-docker/gce-proxy`. The binary is
  `/cloud_sql_proxy`. The image has no entrypoint and no default command, so start it with
  `--entrypoint /cloud_sql_proxy`.

Both lines set `SSL_CERT_FILE` to `/etc/ssl/certs/ca-certificates.crt`.

## Start a Cloud SQL Auth Proxy image

### Line 2

Use a line 2 tag. The entrypoint is `/cloud-sql-proxy`, so arguments you pass go to the proxy. This prints the version.
The version string contains `+container`.

```bash
docker run --rm dhi.io/cloud-sql-connectors-cloud-sql-proxy:<tag> --version
```

A real instance needs an instance connection name, `project:region:instance`. With no instance name, the process exits
with status 1. The first line is `Error: missing instance_connection_name (e.g., project:region:instance)`.

```bash
docker run --rm dhi.io/cloud-sql-connectors-cloud-sql-proxy:<tag>
```

### Line 1

Use a line 1 tag. Pass the binary as the entrypoint. The version line is `Cloud SQL Auth proxy:` followed by the
version, and it does not contain `+container`.

```bash
docker run --rm --entrypoint /cloud_sql_proxy dhi.io/cloud-sql-connectors-cloud-sql-proxy:<tag> --version
```

`docker run` with no command fails in Docker. The process never starts, and the v1 freeze banner is not printed. The
error is `docker: Error response from daemon: no command specified`.

```bash
docker run --rm dhi.io/cloud-sql-connectors-cloud-sql-proxy:<tag>
```

With the entrypoint set and no flags, the binary does start. It prints the v1 freeze banner and exits with status 1. The
banner text is `This is the Cloud SQL Proxy v1. It is no longer receiving active feature development.` The log also
contains `gcloud is not in the path and -instances and -projects are empty`. Upstream describes the move to the current
proxy at https://github.com/GoogleCloudPlatform/cloud-sql-proxy/blob/main/migration-guide.md.

```bash
docker run --rm --entrypoint /cloud_sql_proxy dhi.io/cloud-sql-connectors-cloud-sql-proxy:<tag>
```

## Common Cloud SQL Auth Proxy use cases

### Connect to a Cloud SQL instance

This example uses an existing Cloud SQL for MySQL instance and a service account key file with the Cloud SQL Client
role. Replace `PROJECT:REGION:INSTANCE` with the instance connection name, and `/path/to/key.json` with the key file on
your host. The runtime user is uid 65532, so the key file must be readable by that user.

On line 2, start the proxy and publish the listener on the host loopback address:

```bash
docker run -d --name cloud-sql-proxy \
  -v /path/to/key.json:/config/key.json:ro \
  -p 127.0.0.1:3306:3306 \
  dhi.io/cloud-sql-connectors-cloud-sql-proxy:<tag> \
  --address 0.0.0.0 --port 3306 --credentials-file /config/key.json \
  PROJECT:REGION:INSTANCE
```

On line 1, set the entrypoint and use the v1 flags:

```bash
docker run -d --name cloud-sql-proxy \
  --entrypoint /cloud_sql_proxy \
  -v /path/to/key.json:/config/key.json:ro \
  -p 127.0.0.1:3306:3306 \
  dhi.io/cloud-sql-connectors-cloud-sql-proxy:<tag> \
  -credential_file=/config/key.json \
  -instances=PROJECT:REGION:INSTANCE=tcp:0.0.0.0:3306
```

If the proxy does not start, `docker logs cloud-sql-proxy` shows the reason. Connect with a client on the host. The
query prints `1` when the proxy, the credentials and the instance all work:

```bash
mysql --host 127.0.0.1 --port 3306 --user DB_USER --password --get-server-public-key --execute 'SELECT 1'
```

MySQL 8.4 accounts use `caching_sha2_password`. Over the proxy TCP listener, the first login fails with
`ERROR 2061: Authentication requires secure connection` unless the client passes `--get-server-public-key`.

For PostgreSQL or SQL Server, change `3306` to the engine port in the `--port` flag (line 2), the `tcp:0.0.0.0` listener
(line 1) and the `-p` mapping. The proxy uses these ports when you set no `--port`. Then connect with the client for the
engine:

```bash
# PostgreSQL, port 5432
psql "host=127.0.0.1 port=5432 sslmode=disable dbname=DB_NAME user=DB_USER"

# SQL Server, port 1433
sqlcmd -S tcp:127.0.0.1,1433 -U DB_USER -P DB_PASSWORD -C -Q 'SELECT 1'
```

Current `sqlcmd` versions reject a server certificate they do not trust. The `-C` flag accepts it. The proxy encrypts
the connection to Cloud SQL, so `sslmode=disable` in the `psql` command does not leave the link unencrypted.

Stop the proxy with `docker rm --force cloud-sql-proxy`.

### Listen on an address you can publish

The proxy listens on `127.0.0.1` by default. Another container, or a port published on the host, can reach it only when
the proxy binds a non-loopback address.

On line 2, `--address` defaults to `127.0.0.1`. Pass `--address 0.0.0.0` when you publish the listener. `--port` sets
the first listener port.

On line 1, an instance string of `=tcp:PORT` listens on localhost. To listen on every interface, use
`=tcp:0.0.0.0:PORT`:

`-instances=PROJECT:REGION:INSTANCE=tcp:0.0.0.0:PORT`

`PROJECT:REGION:INSTANCE` is the instance connection name.

### Credentials

A live instance needs that connection name and IAM credentials. On line 2, use Application Default Credentials,
`--token`, or a key file with `--credentials-file`. On line 1, use Application Default Credentials or a key file with
`-credential_file`. The image does not embed credentials.

The runtime user is uid 65532, gid 65532. The home directory `/home/nonroot` is mode `0700`. A credentials file mounted
into the container must be readable by uid 65532.

## Non-hardened images vs. Docker Hardened Images

These points are specific to this image.

### FUSE

The image does not include FUSE or `fusermount`. On line 2, `--fuse` fails before the proxy listens. The process exits
with status 1, and the first line is `Error: --fuse is not supported: fusermount binary not found in PATH or /bin`.

### Shell, package manager, and user

Runtime images have no shell, no package manager, and no `wget`. They run as uid 65532. Dev tags include a shell and run
as root. On a dev tag:

```bash
docker run --rm --entrypoint sh dhi.io/cloud-sql-connectors-cloud-sql-proxy:<tag>-dev -c 'id'
```

The command prints `uid=0(root) gid=0(root) groups=0(root)`.

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
