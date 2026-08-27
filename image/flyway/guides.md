## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Run a Flyway container

Run the following `docker run` command to run a Flyway container.

```bash
$ docker run --rm dhi.io/flyway:11.9-jre23 info
```

### Basic database migration

To migrate a database, you need to provide database connection details and mount your migration files:

```bash
$ docker run --rm \
  -v $(pwd)/sql:/flyway/sql \
  dhi.io/flyway:11.9-jre23 \
  -url=jdbc:postgresql://localhost:5432/mydb \
  -user=myuser \
  -password=mypassword \
  migrate
```

### Common Flyway commands

- **info**: Display migration info
- **migrate**: Migrate the database
- **clean**: Drop all objects in the configured schemas
- **validate**: Validate applied migrations against resolved ones
- **baseline**: Baseline an existing database
- **repair**: Repair the schema history table

### Environment variables

You can use environment variables to configure Flyway:

```bash
$ docker run --rm \
  -v $(pwd)/sql:/flyway/sql \
  -e FLYWAY_URL=jdbc:postgresql://localhost:5432/mydb \
  -e FLYWAY_USER=myuser \
  -e FLYWAY_PASSWORD=mypassword \
  dhi.io/flyway:11.9-jre23 \
  migrate
```

### Configuration file

You can also mount a configuration file:

```bash
$ docker run --rm \
  -v $(pwd)/conf:/flyway/conf \
  -v $(pwd)/sql:/flyway/sql \
  dhi.io/flyway:11.9-jre23 \
  migrate
```

### Additional examples

#### MySQL database migration

```bash
$ docker run --rm \
  -v $(pwd)/sql:/flyway/sql \
  -e FLYWAY_URL=jdbc:mysql://localhost:3306/mydb \
  -e FLYWAY_USER=root \
  -e FLYWAY_PASSWORD=mypassword \
  dhi.io/flyway:11.9-jre23 \
  migrate
```

#### SQL Server database migration

```bash
$ docker run --rm \
  -v $(pwd)/sql:/flyway/sql \
  -e FLYWAY_URL=jdbc:sqlserver://localhost:1433;databaseName=mydb \
  -e FLYWAY_USER=sa \
  -e FLYWAY_PASSWORD=mypassword \
  dhi.io/flyway:11.9-jre23 \
  migrate
```

#### Oracle database migration

```bash
$ docker run --rm \
  -v $(pwd)/sql:/flyway/sql \
  -e FLYWAY_URL=jdbc:oracle:thin:@localhost:1521:XE \
  -e FLYWAY_USER=system \
  -e FLYWAY_PASSWORD=mypassword \
  dhi.io/flyway:11.9-jre23 \
  migrate
```

#### Check migration status

```bash
$ docker run --rm \
  -e FLYWAY_URL=jdbc:postgresql://localhost:5432/mydb \
  -e FLYWAY_USER=myuser \
  -e FLYWAY_PASSWORD=mypassword \
  dhi.io/flyway:11.9-jre23 \
  info
```

#### Validate migrations

```bash
$ docker run --rm \
  -v $(pwd)/sql:/flyway/sql \
  -e FLYWAY_URL=jdbc:postgresql://localhost:5432/mydb \
  -e FLYWAY_USER=myuser \
  -e FLYWAY_PASSWORD=mypassword \
  dhi.io/flyway:11.9-jre23 \
  validate
```

#### Baseline existing database

```bash
$ docker run --rm \
  -e FLYWAY_URL=jdbc:postgresql://localhost:5432/mydb \
  -e FLYWAY_USER=myuser \
  -e FLYWAY_PASSWORD=mypassword \
  -e FLYWAY_BASELINE_VERSION=1.0 \
  -e FLYWAY_BASELINE_DESCRIPTION="Initial baseline" \
  dhi.io/flyway:11.9-jre23 \
  baseline
```

#### Using with Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: "3.8"
services:
  postgres:
    image: dhi.io/postgres
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  flyway:
    image: dhi.io/flyway:11.9-jre23
    command: migrate
    volumes:
      - ./sql:/flyway/sql
      - ./conf:/flyway/conf
    environment:
      FLYWAY_URL: jdbc:postgresql://postgres:5432/mydb
      FLYWAY_USER: myuser
      FLYWAY_PASSWORD: mypassword
    depends_on:
      - postgres

volumes:
  postgres_data:
```

Run with Docker Compose:

```bash
$ docker-compose up flyway
```

#### Advanced configuration with multiple schemas

```bash
$ docker run --rm \
  -v $(pwd)/sql:/flyway/sql \
  -e FLYWAY_URL=jdbc:postgresql://localhost:5432/mydb \
  -e FLYWAY_USER=myuser \
  -e FLYWAY_PASSWORD=mypassword \
  -e FLYWAY_SCHEMAS=public,app,audit \
  -e FLYWAY_DEFAULT_SCHEMA=app \
  dhi.io/flyway:11.9-jre23 \
  migrate
```

#### Using configuration file with custom settings

Create a `flyway.conf` file:

```properties
flyway.url=jdbc:postgresql://localhost:5432/mydb
flyway.user=myuser
flyway.password=mypassword
flyway.schemas=public,app
flyway.table=schema_version
flyway.locations=filesystem:/flyway/sql
flyway.validateOnMigrate=true
flyway.outOfOrder=false
flyway.baselineOnMigrate=true
```

Run with configuration file:

```bash
$ docker run --rm \
  -v $(pwd)/conf/flyway.conf:/flyway/conf/flyway.conf \
  -v $(pwd)/sql:/flyway/sql \
  dhi.io/flyway:11.9-jre23 \
  migrate
```

#### Repair schema history table

```bash
$ docker run --rm \
  -e FLYWAY_URL=jdbc:postgresql://localhost:5432/mydb \
  -e FLYWAY_USER=myuser \
  -e FLYWAY_PASSWORD=mypassword \
  dhi.io/flyway:11.9-jre23 \
  repair
```

#### Clean database (use with caution)

```bash
$ docker run --rm \
  -e FLYWAY_URL=jdbc:postgresql://localhost:5432/mydb \
  -e FLYWAY_USER=myuser \
  -e FLYWAY_PASSWORD=mypassword \
  -e FLYWAY_CLEAN_DISABLED=false \
  dhi.io/flyway:11.9-jre23 \
  clean
```

#### Using with secrets from files

```bash
$ docker run --rm \
  -v $(pwd)/sql:/flyway/sql \
  -v $(pwd)/secrets/db-password:/run/secrets/db-password \
  -e FLYWAY_URL=jdbc:postgresql://localhost:5432/mydb \
  -e FLYWAY_USER=myuser \
  -e FLYWAY_PASSWORD_FILE=/run/secrets/db-password \
  dhi.io/flyway:11.9-jre23 \
  migrate
```

#### Custom migration location

```bash
$ docker run --rm \
  -v $(pwd)/database/migrations:/flyway/custom-migrations \
  -e FLYWAY_URL=jdbc:postgresql://localhost:5432/mydb \
  -e FLYWAY_USER=myuser \
  -e FLYWAY_PASSWORD=mypassword \
  -e FLYWAY_LOCATIONS=filesystem:/flyway/custom-migrations \
  dhi.io/flyway:11.9-jre23 \
  migrate
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

### Flyway-specific considerations

#### Migration files

Flyway looks for migration files in the `/flyway/sql` directory by default. When using the Docker Hardened Image, mount
your migration files to this directory:

```bash
$ docker run --rm -v $(pwd)/migrations:/flyway/sql dhi.io/flyway:11.9-jre23 migrate
```

#### Configuration

Flyway configuration can be provided via:

- Command line arguments
- Environment variables (prefixed with `FLYWAY_`)
- Configuration files mounted to `/flyway/conf`

#### Database drivers

The Flyway image includes drivers for common databases including PostgreSQL, MySQL, Oracle, SQL Server, and others. For
specialized databases, you may need to add additional JDBC drivers to your custom image.
