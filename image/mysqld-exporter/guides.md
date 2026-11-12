## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Run MySQL Server Exporter

Use the image directly with configuration passed as flags, a MySQL client config file, or environment variables. Replace
`<tag>` with the image tag you want to run.

Create a dedicated MySQL user with minimal privileges (recommended):

```
CREATE USER 'exporter'@'%' IDENTIFIED BY 'strong-password';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
```

Run the exporter pointing at a MySQL server using flags and an environment variable for the password:

```
$ docker run -d \
  --name mysqld-exporter \
  -p 9104:9104 \
  -e MYSQLD_EXPORTER_PASSWORD=strong-password \
  dhi.io/mysqld-exporter:<tag> \
  --mysqld.address=mysql:3306 \
  --mysqld.username=exporter
```

Alternatively, mount a MySQL client config and let the exporter read credentials from it:

```
# config.my-cnf contents example:
# [client]
# user=exporter
# password=strong-password

$ docker run -d \
  --name mysqld-exporter \
  -p 9104:9104 \
  -v $PWD/config.my-cnf:/config.my-cnf:ro \
  dhi.io/mysqld-exporter:<tag> \
  --config.my-cnf=/config.my-cnf \
  --mysqld.address=mysql:3306
```

Metrics are exposed at `http://localhost:9104/metrics`.

#### Multi-target scraping with /probe

You can run one exporter for many MySQL targets using the `/probe` endpoint. Start the exporter with your credential
config and then pass the target at request time:

```
$ docker run -d \
  --name mysqld-exporter \
  -p 9104:9104 \
  -v $PWD/config.my-cnf:/config.my-cnf:ro \
  dhi.io/mysqld-exporter:<tag> \
  --config.my-cnf=/config.my-cnf

# Scrape different targets:
http://localhost:9104/probe?target=mysql-a:3306
http://localhost:9104/probe?target=unix:///run/mysqld/mysqld.sock
```

To avoid putting credentials in the URL, you can provide multiple credential sections in the config file and select one
with `auth_module`:

```
# Example config.my-cnf
[client]               # default
user=exporter
password=exporter123

[client.reporting]     # optional alt creds
user=reporter
password=reporter123
```

Example request choosing the `client.reporting` credentials:

```
http://localhost:9104/probe?target=mysql-b:3306&auth_module=client.reporting
```

#### Common options

- `--web.listen-address` (default: `:9104`) – Address to listen on
- `--web.telemetry-path` (default: `/metrics`) – Metrics path
- `--mysqld.address` (default: `localhost:3306`) – MySQL host:port or Unix socket (use `unix:///...`)
- `--mysqld.username` – MySQL username (use with `MYSQLD_EXPORTER_PASSWORD` or config file)
- `--config.my-cnf` (default: `~/.my.cnf`) – Path to MySQL client config with credentials
- Collector toggles via flags like `--collect.global_status`, `--no-collect.slave_status`, etc.

TLS and basic auth for the HTTP endpoint can be configured with `--web.config.file` (see Prometheus exporter-toolkit
docs).

### Docker Compose example

Save as `docker-compose.yml` and run `docker compose up -d`:

```yaml
version: "3.8"
services:
  mysql:
    image: mysql:8
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpass123
      MYSQL_DATABASE: testdb
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-prootpass123"]
      interval: 10s
      timeout: 5s
      retries: 10
    ports:
      - "3306:3306"
    networks: [monitoring]

  mysqld-exporter:
    image: dhi.io/mysqld-exporter:<tag>
    container_name: mysqld-exporter
    command:
      - --mysqld.address=mysql:3306
      - --mysqld.username=root
    environment:
      MYSQLD_EXPORTER_PASSWORD: rootpass123
    ports:
      - "9104:9104"
    depends_on:
      - mysql
    networks: [monitoring]

networks:
  monitoring: {}
```

This setup exposes metrics at `http://localhost:9104/metrics` and mirrors the configuration used in the automated tests
for this image.

Note: the repository's automated test uses `image/mysqld-exporter/tests/compose/compose.yaml`, which publishes MySQL's
port (`3306:3306`) so the test harness can map the service port to the host. If you run the compose stack locally for
testing, ensure the `mysql` service exposes `3306` (as shown above) so the exporter can connect to the database.

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
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                            |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the Tags tab for this repository. To view what packages are already installed in an image variant, select the
   Tags tab for this repository, and then select a tag.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use Docker
Debug(https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides a shell,
common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists during the
debugging session.

### Permissions

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the Tags tab for this repository.

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

To see if a shell is available in an image variant and which one, select the Tags tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the Tags tab for this repository, select a tag, and
then select the Specifications tab.
