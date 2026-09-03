## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/supabase-studio:<tag>`
- Mirrored image: `<your-namespace>/dhi-supabase-studio:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This Docker Hardened image packages Supabase Studio, the Next.js standalone server that serves the self-hosted Supabase
dashboard. On its own it renders the UI, but the table editor, SQL editor, auth and user management, storage browser,
and other features require a running Postgres database and the other Supabase backend services to be functional.

### Start a Supabase Studio instance

```bash
$ docker run -d --name supabase-studio -p 127.0.0.1:3000:3000 dhi.io/supabase-studio:<tag>
$ curl --fail http://localhost:3000/
$ docker rm --force supabase-studio
```

The image starts the server with its default `CMD` (`node apps/studio/server.js`), so no override is needed. A
shell-free compatibility launcher preserves upstream's behavior for command overrides such as `--version` and
`node -e '...'`. Studio listens on port 3000 and the page loads with this command alone, but without
`STUDIO_PG_META_URL` and the other backend variables described below, dashboard features that call the API will fail.
See the use cases below for a functional setup.

Studio has no authentication of its own: anyone who can reach port 3000 can operate the dashboard, and once a database
is connected, run arbitrary SQL through it. The examples in this guide therefore bind the port to the host's loopback
interface. To serve other machines, keep Studio unpublished and front it with the stack's API gateway or a reverse proxy
that enforces sign-in, as upstream's self-hosted stack does (see [Advanced setups](#advanced-setups)).

## Common Supabase Studio use cases

### Connect Studio to Postgres with postgres-meta

This wires Studio to a Postgres database through `postgres-meta`, which is what Studio's table and SQL editors use to
introspect and query the database. This mirrors the `studio`, `meta`, and `db` services in upstream's
[`docker/docker-compose.yml`](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml).

```yaml
services:
  studio:
    image: dhi.io/supabase-studio:<tag>
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_PASSWORD: your-super-secret-password
      POSTGRES_USER_READ_WRITE: postgres
      SNIPPETS_MANAGEMENT_FOLDER: /app/snippets
      EDGE_FUNCTIONS_MANAGEMENT_FOLDER: /app/edge-functions
      DEFAULT_ORGANIZATION_NAME: Default Organization
      DEFAULT_PROJECT_NAME: Default Project
    healthcheck:
      test:
        - CMD
        - node
        - -e
        - "fetch('http://localhost:3000/api/platform/profile').then((r) => { if (r.status !== 200) throw new Error(r.status) })"
      interval: 5s
      timeout: 5s
      retries: 20
    depends_on:
      meta:
        condition: service_healthy

  meta:
    image: supabase/postgres-meta:v0.96.6
    environment:
      PG_META_PORT: "8080"
      PG_META_DB_HOST: db
      PG_META_DB_NAME: postgres
      PG_META_DB_USER: postgres
      PG_META_DB_PASSWORD: your-super-secret-password
    healthcheck:
      test:
        - CMD
        - node
        - -e
        - "fetch('http://localhost:8080/health').then((r) => { if (!r.ok) throw new Error(r.status) })"
      interval: 2s
      timeout: 5s
      retries: 30
    depends_on:
      db:
        condition: service_healthy

  db:
    image: supabase/postgres:17.6.1.136
    environment:
      POSTGRES_HOST: /var/run/postgresql
      PGPORT: "5432"
      POSTGRES_PORT: "5432"
      PGPASSWORD: your-super-secret-password
      POSTGRES_PASSWORD: your-super-secret-password
      POSTGRES_DB: postgres
      JWT_SECRET: replace-with-at-least-32-characters
      JWT_EXP: "3600"
    command:
      - postgres
      - -c
      - config_file=/etc/postgresql/postgresql.conf
      - -c
      - log_min_messages=fatal
    healthcheck:
      test:
        - CMD-SHELL
        - pg_isready -U postgres -d postgres
      interval: 2s
      timeout: 5s
      retries: 30
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:
```

Run `docker compose up -d`, then open `http://localhost:3000`. With `STUDIO_PG_META_URL` wired, Studio's API executes
SQL against `db` without requiring credentials from the caller, which is why the example publishes port 3000 on the
loopback interface only. The table editor introspects `db` through `meta`, while the SQL editor connects to `db`
directly as the role named in `POSTGRES_USER_READ_WRITE`. Without that variable, Studio defaults to the `supabase_admin`
role. This minimal example uses `postgres` explicitly; upstream's full stack configures the complete Supabase role
model. `SNIPPETS_MANAGEMENT_FOLDER` and `EDGE_FUNCTIONS_MANAGEMENT_FOLDER` point Studio at the directories the image
provisions for saved SQL snippets and edge functions, as upstream's compose does — without them, the SQL editor can't
save or list snippets and the Edge Functions page fails. Both directories are writable by the nonroot user, so no bind
mount is required; mount a volume over `/app/snippets` if saved snippets should survive container replacement.
`DEFAULT_ORGANIZATION_NAME` and `DEFAULT_PROJECT_NAME` only control the labels Studio displays for the local project;
they don't need to match anything else.

### Run as part of the full self-hosted Supabase stack

In production, Studio is one service in Supabase's full self-hosted stack, fronted by an API gateway and running
alongside `gotrue`, `postgrest`, `realtime`, `storage-api`, and `supavisor`. To use the hardened image there, take
upstream's [`docker/docker-compose.yml`](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml) and
replace the `studio` service's `image:` line with `dhi.io/supabase-studio:<tag>`; every other service and environment
variable stays the same. For the full setup, including generating API keys and JWT secrets, see the
[Self-Hosting with Docker](https://supabase.com/docs/guides/self-hosting/docker) guide.

### Advanced setups

- **Authentication:** Studio has no built-in sign-in; whoever reaches port 3000 can operate the dashboard and run SQL.
  Before exposing Studio beyond localhost, require dashboard credentials through the stack's API gateway, as upstream's
  full self-hosted stack does, or through equivalent reverse-proxy authentication; see the
  [Self-Hosting with Docker](https://supabase.com/docs/guides/self-hosting/docker) guide.
- **TLS termination:** put a reverse proxy or the stack's API gateway in front of Studio and terminate TLS there; see
  the [Self-Hosting with Docker](https://supabase.com/docs/guides/self-hosting/docker) guide.

## Non-hardened images vs. Docker Hardened Images

Runtime variants of this image run as the nonroot `node` user (uid 1000), whereas the upstream `supabase/studio` image
runs as root. The application payload lives at `/usr/lib/supabase-studio`, and `/app` is kept as a compatibility symlink
to it, so `node apps/studio/server.js` resolves the same way it does upstream, and the self-hosted stack's bind mounts
(`./volumes/snippets:/app/snippets`, `./volumes/functions:/app/edge-functions`) keep working unchanged. Both mount
targets exist in the image and are writable by the nonroot user, so with `SNIPPETS_MANAGEMENT_FOLDER` and
`EDGE_FUNCTIONS_MANAGEMENT_FOLDER` set (as in the examples above and in upstream's compose), saved SQL snippets also
work without a bind mount; upstream relies on running as root to create that folder on first use. The Node.js
interpreter lives at `/usr/bin/node` and is on `PATH`, not at `/usr/local/bin/node` as in the upstream image; invoke it
as `node`, or update any absolute interpreter paths when migrating.

The upstream image also ships upstream's committed development `.env` (demo JWTs and an insecure dashboard password) and
compiles shared hosted-project and hCaptcha test values into the client. This package removes `.env` before the Next.js
build and fails if those upstream values remain in the artifact. Runtime server settings come from real environment
variables, as in the examples above and in upstream's compose file. The optional Cmd-K/AI and hCaptcha integrations use
build-time `NEXT_PUBLIC_*` settings, so this hardened image deliberately does not preconfigure them with upstream's
shared defaults.

Unlike the upstream OCI image, this definition cannot embed a healthcheck in its image metadata. The Compose example
above supplies the equivalent shell-free probe. In Kubernetes, configure the same endpoint as a readiness probe:

```yaml
readinessProbe:
  httpGet:
    path: /api/platform/profile
    port: 3000
  periodSeconds: 5
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
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
