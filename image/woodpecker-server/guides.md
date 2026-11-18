## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/woodpecker-server:<tag>`
- Mirrored image: `<your-namespace>/dhi-woodpecker-server:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Replace `<tag>` with the variant you want. For example, `3` is the Debian runtime image, `3-alpine` is the Alpine
runtime image, and `3-dev` and `3-fips` are the Debian dev and FIPS variants. Configuration, forge setup, and pipeline
syntax are documented at https://woodpecker-ci.org/docs/administration/configuration/server.

This image contains the Woodpecker server only: the web UI, the API, and the gRPC endpoint that agents connect to. It
doesn't include the Woodpecker agent or CLI. Upstream publishes those as separate images, for example
`docker.io/woodpeckerci/woodpecker-agent`.

## Start a Woodpecker server image

The server runs `/bin/woodpecker-server` as the `woodpecker` user (UID and GID 1000), the same entry point and user as
the upstream `woodpeckerci/woodpecker-server` image. It listens on these ports:

- `8000`: the web UI and API (`WOODPECKER_SERVER_ADDR`)
- `9000`: plaintext gRPC for agents (`WOODPECKER_GRPC_ADDR`)
- `443`: HTTPS, only when `WOODPECKER_SERVER_CERT` and `WOODPECKER_SERVER_KEY` are set (`WOODPECKER_SERVER_ADDR_TLS`)

The server stores its default SQLite database at `/var/lib/woodpecker/woodpecker.sqlite`. Mount a volume at
`/var/lib/woodpecker` to keep users, repositories, and pipeline history across restarts.

The server needs a forge to sign users in. The following example uses Gitea. Register an OAuth application in Gitea with
the callback URL `<WOODPECKER_HOST>/authorize`, for example `http://localhost:8000/authorize`, and use its client ID and
secret below. For GitHub, GitLab, Forgejo, and Bitbucket, see the
[forge documentation](https://woodpecker-ci.org/docs/administration/configuration/forges/overview).

```bash
$ export WOODPECKER_AGENT_SECRET="$(openssl rand -hex 32)"
$ docker volume create woodpecker-server-data
$ docker run -d --name woodpecker-server \
    -p 8000:8000 -p 9000:9000 \
    -v woodpecker-server-data:/var/lib/woodpecker \
    -e WOODPECKER_HOST=http://localhost:8000 \
    -e WOODPECKER_GITEA=true \
    -e WOODPECKER_GITEA_URL=https://gitea.example.com \
    -e WOODPECKER_GITEA_CLIENT=your-oauth-client-id \
    -e WOODPECKER_GITEA_SECRET=your-oauth-client-secret \
    -e WOODPECKER_AGENT_SECRET="$WOODPECKER_AGENT_SECRET" \
    dhi.io/woodpecker-server:<tag>
```

The log shows `starting Woodpecker server with version '3.20.1'` and `starting http server ...`. Then open
http://localhost:8000 to reach the web UI, or check the health and version endpoints:

```bash
$ curl -i http://localhost:8000/healthz
$ curl http://localhost:8000/version
```

`/healthz` returns `204 No Content`. `/version` returns
`{"source":"https://github.com/woodpecker-ci/woodpecker","version":"3.20.1"}`.

A named volume picks up the image's `1000:1000` ownership of `/var/lib/woodpecker` on first use. If you bind-mount a
host directory instead, `chown` it to `1000:1000` first. Otherwise the server can't create its database and logs
`failed to setup store: unable to open database file`. Volumes created for the upstream image are already owned by UID
1000 and work unchanged.

To print the version without starting the server:

```bash
$ docker run --rm dhi.io/woodpecker-server:<tag> --version
```

The command prints `woodpecker-server version 3.20.1`.

### Environment variables

These are the variables used in this guide. For every other setting, see the
[server configuration reference](https://woodpecker-ci.org/docs/administration/configuration/server).

| Variable                           | Description                                                                                                     | Default                                 | Required                    |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------- | --------------------------------------- | --------------------------- |
| `WOODPECKER_HOST`                  | Public URL of the server, used for OAuth callbacks and links                                                    | (none)                                  | Yes                         |
| `WOODPECKER_AGENT_SECRET`          | Shared secret that agents use to authenticate to the server                                                     | (none)                                  | Yes, to connect agents      |
| `WOODPECKER_GITEA`                 | Enables the Gitea forge. Other forges use their own `WOODPECKER_<FORGE>` variables.                             | `false`                                 | One forge is required       |
| `WOODPECKER_GITEA_URL`             | URL of the Gitea instance                                                                                       | (none)                                  | Yes, with Gitea             |
| `WOODPECKER_GITEA_CLIENT`          | Gitea OAuth client ID                                                                                           | (none)                                  | Yes, with Gitea             |
| `WOODPECKER_GITEA_SECRET`          | Gitea OAuth client secret                                                                                       | (none)                                  | Yes, with Gitea             |
| `WOODPECKER_ADMIN`                 | Comma-separated forge usernames that become admins when they sign in                                            | (none)                                  | No                          |
| `WOODPECKER_GRPC_SECRET`           | Secret that signs agent gRPC tokens. If unset, the server generates a new one on every start and logs a warning | (generated)                             | Recommended                 |
| `WOODPECKER_DATABASE_DRIVER`       | Database driver: `sqlite3`, `postgres`, or `mysql`                                                              | `sqlite3`                               | No                          |
| `WOODPECKER_DATABASE_DATASOURCE`   | Database connection string                                                                                      | `/var/lib/woodpecker/woodpecker.sqlite` | Yes, for `postgres`/`mysql` |
| `WOODPECKER_SERVER_CERT`           | Path to a TLS certificate. With `WOODPECKER_SERVER_KEY`, enables HTTPS on `:443`                                | (none)                                  | No                          |
| `WOODPECKER_SERVER_KEY`            | Path to the TLS private key                                                                                     | (none)                                  | No                          |
| `WOODPECKER_DISABLE_VERSION_CHECK` | Turns off the admin UI's update check against woodpecker-ci.org                                                 | `true` in this image                    | No                          |

## Common Woodpecker server use cases

### Run a server and an agent with Docker Compose

Pipelines run on agents. This Compose file runs the server from this image with the upstream Docker agent, which
connects to the server over gRPC on port 9000 and starts pipeline steps as containers through the host's Docker socket.
Keep the agent on the same 3.x release line as the server.

Create a `.env` file with your forge settings and two generated secrets:

```bash
$ cat > .env <<EOF
WOODPECKER_HOST=http://localhost:8000
WOODPECKER_ADMIN=your-gitea-username
WOODPECKER_GITEA_URL=https://gitea.example.com
WOODPECKER_GITEA_CLIENT=your-oauth-client-id
WOODPECKER_GITEA_SECRET=your-oauth-client-secret
WOODPECKER_AGENT_SECRET=$(openssl rand -hex 32)
WOODPECKER_GRPC_SECRET=$(openssl rand -hex 32)
EOF
```

Save the following as `compose.yaml`:

```yaml
services:
  woodpecker-server:
    image: dhi.io/woodpecker-server:<tag>
    ports:
      - "8000:8000"
    volumes:
      - woodpecker-server-data:/var/lib/woodpecker
    environment:
      WOODPECKER_HOST: ${WOODPECKER_HOST}
      WOODPECKER_ADMIN: ${WOODPECKER_ADMIN}
      WOODPECKER_GITEA: "true"
      WOODPECKER_GITEA_URL: ${WOODPECKER_GITEA_URL}
      WOODPECKER_GITEA_CLIENT: ${WOODPECKER_GITEA_CLIENT}
      WOODPECKER_GITEA_SECRET: ${WOODPECKER_GITEA_SECRET}
      WOODPECKER_AGENT_SECRET: ${WOODPECKER_AGENT_SECRET}
      WOODPECKER_GRPC_SECRET: ${WOODPECKER_GRPC_SECRET}

  woodpecker-agent:
    image: docker.io/woodpeckerci/woodpecker-agent:v3
    command: agent
    restart: always
    depends_on:
      - woodpecker-server
    volumes:
      - woodpecker-agent-config:/etc/woodpecker
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      WOODPECKER_SERVER: woodpecker-server:9000
      WOODPECKER_AGENT_SECRET: ${WOODPECKER_AGENT_SECRET}

volumes:
  woodpecker-server-data:
  woodpecker-agent-config:
```

Start both services:

```bash
$ docker compose up -d
```

The agent may log `cannot connect to woodpecker-server:9000, retrying in 2s` once while the server starts. It then logs
`starting Woodpecker agent` and stores its registration in `/etc/woodpecker/agent.conf`. Port 9000 isn't published
because the agent reaches the server on the Compose network. Publish it only for agents on other hosts, and put a
TLS-terminating proxy in front of it, because the server's gRPC listener is plaintext. See the
[agent documentation](https://woodpecker-ci.org/docs/administration/configuration/agent) for agent settings.

### Use PostgreSQL instead of SQLite

Set `WOODPECKER_DATABASE_DRIVER` and `WOODPECKER_DATABASE_DATASOURCE` to use PostgreSQL. Woodpecker creates its tables
on first start, but not the database itself, so this example lets the PostgreSQL image create it. It uses the `.env`
file from the previous example. Add the `woodpecker-agent` service from that example to run pipelines.

```yaml
services:
  woodpecker-server:
    image: dhi.io/woodpecker-server:<tag>
    ports:
      - "8000:8000"
    environment:
      WOODPECKER_HOST: ${WOODPECKER_HOST}
      WOODPECKER_ADMIN: ${WOODPECKER_ADMIN}
      WOODPECKER_GITEA: "true"
      WOODPECKER_GITEA_URL: ${WOODPECKER_GITEA_URL}
      WOODPECKER_GITEA_CLIENT: ${WOODPECKER_GITEA_CLIENT}
      WOODPECKER_GITEA_SECRET: ${WOODPECKER_GITEA_SECRET}
      WOODPECKER_AGENT_SECRET: ${WOODPECKER_AGENT_SECRET}
      WOODPECKER_GRPC_SECRET: ${WOODPECKER_GRPC_SECRET}
      WOODPECKER_DATABASE_DRIVER: postgres
      WOODPECKER_DATABASE_DATASOURCE: postgres://woodpecker:woodpecker@db:5432/woodpecker?sslmode=disable
    depends_on:
      db:
        condition: service_healthy

  db:
    image: dhi.io/postgres:18
    environment:
      POSTGRES_DB: woodpecker
      POSTGRES_USER: woodpecker
      POSTGRES_PASSWORD: woodpecker
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "woodpecker", "-d", "woodpecker"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  postgres-data:
```

Replace the example password before production use.

### Serve HTTPS from the server

To terminate TLS in Woodpecker instead of a reverse proxy, mount a certificate and key that UID 1000 can read, and set
`WOODPECKER_SERVER_CERT` and `WOODPECKER_SERVER_KEY`. The server then serves HTTPS on port 443, and port 8000 answers
with a `301` redirect to `WOODPECKER_HOST`.

```bash
$ docker run -d --name woodpecker-server \
    -p 443:443 -p 9000:9000 \
    -v woodpecker-server-data:/var/lib/woodpecker \
    -v "$(pwd)/certs:/etc/woodpecker/certs:ro" \
    -e WOODPECKER_HOST=https://localhost \
    -e WOODPECKER_SERVER_CERT=/etc/woodpecker/certs/server.crt \
    -e WOODPECKER_SERVER_KEY=/etc/woodpecker/certs/server.key \
    -e WOODPECKER_GITEA=true \
    -e WOODPECKER_GITEA_URL=https://gitea.example.com \
    -e WOODPECKER_GITEA_CLIENT=your-oauth-client-id \
    -e WOODPECKER_GITEA_SECRET=your-oauth-client-secret \
    -e WOODPECKER_AGENT_SECRET="$WOODPECKER_AGENT_SECRET" \
    dhi.io/woodpecker-server:<tag>
```

Port 443 is privileged. Docker Engine 20.10 and later lets the nonroot user bind it, but Kubernetes doesn't by default.
There, set `WOODPECKER_SERVER_ADDR_TLS=:8443` and expose 8443 instead.

On FIPS variants, the HTTPS listener accepts only FIPS-approved TLS cipher suites and key exchange groups. Clients that
offer only ChaCha20-Poly1305 or only X25519 fail the handshake. Use clients that support AES-GCM and a NIST curve such
as P-256.

### Health checks

Upstream's image declares a `HEALTHCHECK` that runs `woodpecker-server ping`. That command exits `0` even when no server
is listening, so it always reports healthy. This image declares no `HEALTHCHECK`, and the runtime image has no shell or
HTTP client to run one. Check `/healthz` on port 8000 from your orchestrator instead. It returns `204` when the server
is up. For example, in a Kubernetes container spec:

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8000
readinessProbe:
  httpGet:
    path: /healthz
    port: 8000
```

When the server serves HTTPS itself, port 8000 only redirects. Probe the HTTPS port with `scheme: HTTPS` instead.

## Non-hardened images vs. Docker Hardened Images

The entry point, user (UID and GID 1000), working directory, data directory, and ports 8000, 9000, and 443 match the
upstream `woodpeckerci/woodpecker-server` image. To migrate an existing deployment, replace the image reference and keep
your volumes and environment. The differences are:

- **Version check:** `WOODPECKER_DISABLE_VERSION_CHECK` is `true`, so the admin UI doesn't call woodpecker-ci.org to
  check for updates. Set it to `false` to restore upstream behavior.
- **Health check:** the image has no `HEALTHCHECK`. Use an HTTP check of `/healthz`, as described in
  [Health checks](#health-checks). The `ping` subcommand still exists for Compose files that call it.
- **Server only:** the agent and CLI aren't included. Run them from their own images.
- **Dev variants:** `dev` tags run as root and include `bash`, `coreutils`, `findutils`, and `apt` (Debian) or `apk`
  (Alpine). Their `woodpecker-server` binary keeps its debug symbols, which helps when you debug the server.

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
