## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start an Unleash instance

Unleash requires a PostgreSQL database. First, create a Docker network and start a PostgreSQL container:

```
docker network create unleash-net
docker run -d --name postgres --network unleash-net \
    -e POSTGRES_DB=unleash \
    -e POSTGRES_USER=unleash \
    -e POSTGRES_PASSWORD=changeme \
    postgres:16
```

Then start Unleash:

```
docker run -d --name unleash \
    --network unleash-net \
    -p 4242:4242 \
    -e DATABASE_URL="postgres://unleash:changeme@postgres:5432/unleash?sslmode=disable" \
    dhi.io/unleash:<tag>
```

Navigate to `http://localhost:4242` in your browser. The default admin credentials are `admin` / `unleash4all`.

### Configuration

Unleash is configured through environment variables. For a complete list, see the
[Unleash configuration documentation](https://docs.getunleash.io/reference/configuration).

Unleash attempts SSL connections to PostgreSQL by default. When connecting to PostgreSQL without SSL, append
`?sslmode=disable` to the `DATABASE_URL` connection string.

### Docker Compose example

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: unleash
      POSTGRES_USER: unleash
      POSTGRES_PASSWORD: changeme
    volumes:
      - postgres-data:/var/lib/postgresql/data
  unleash:
    image: dhi.io/unleash:<tag>
    ports:
      - "4242:4242"
    environment:
      DATABASE_URL: "postgres://unleash:changeme@postgres:5432/unleash?sslmode=disable"
    depends_on:
      - postgres
volumes:
  postgres-data:
```

## Differences from upstream

The Docker Hardened Image differs from the upstream `unleashorg/unleash-server` image in the following ways:

| Property   | Upstream                      | DHI                              |
| :--------- | :---------------------------- | :------------------------------- |
| Base image | `node:22-alpine`              | Debian 13 (minimal)              |
| User       | `node`                        | `nonroot` (uid 65532)            |
| Workdir    | `/unleash`                    | `/opt/unleash`                   |
| Entrypoint | Node image entrypoint wrapper | `node` directly                  |
| Shell      | Available (ash)               | Not available in runtime variant |

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
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the **Tags** tab for this repository. To view what packages are already installed in an image variant, select
   the **Tags** tab for this repository, and then select a tag.

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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Troubleshooting

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

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

The upstream image inherits the Node image's `docker-entrypoint.sh` wrapper, which prepends `node` for Node.js flags and
scripts before executing the command. The Docker Hardened Image runs `node` directly with `/opt/unleash/dist/server.js`
as the default command. Default startup and Node.js flags such as `--version` work the same way, but shell-style command
overrides aren't supported by the runtime variant because it doesn't include a shell. Use Docker Debug or a `dev`
variant for interactive shell-based debugging.

### Database connection

Unleash must be able to reach a PostgreSQL server. Ensure the `DATABASE_URL` environment variable is set correctly and
that both containers are on the same Docker network. If using Docker Compose, the `depends_on` directive ensures
PostgreSQL starts before Unleash.

### Database migrations

Unleash automatically runs database migrations on startup. If you see migration errors, ensure the database user has
sufficient privileges to create tables and run migrations.
