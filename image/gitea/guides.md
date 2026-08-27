## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this gitea image

This Docker Hardened gitea image models Gitea's own rootless deployment (the upstream `gitea/gitea:<tag>-rootless`
image): it runs as the nonroot `git` user (UID/GID 1000), has no `sshd`, and relies solely on Gitea's builtin SSH
server. The image includes Gitea itself, `git`, `openssh-keygen` (for host key generation), `gnupg` (for commit
signature verification), and `dumb-init` as PID 1 to reap zombie processes spawned by Git and SSH sessions.

Gitea provides Git repository hosting, code review with pull requests, issue tracking and project boards, a wiki, a
package registry (npm, Maven, Docker, and more), and CI/CD through Gitea Actions. SQLite, PostgreSQL, and MySQL are all
supported as the backing database; SQLite is the default and requires no additional services.

If you are migrating from the default root upstream image (`gitea/gitea:<tag>`), adopt this rootless layout (UID/GID
1000, `/var/lib/gitea` + `/etc/gitea`, builtin SSH on 2222). See
[Install with Docker rootless](https://docs.gitea.com/installation/install-with-docker-rootless) for background.

### Start a gitea container

The image ships with no default `CMD`. The entry point script provisions a fresh `/etc/gitea/app.ini` on first run (from
environment variables), applies any `GITEA__SECTION__KEY` overrides, and then execs `gitea web`. Persistent data lives
under `/var/lib/gitea` and configuration under `/etc/gitea`; both paths are pre-created in the image with ownership
`1000:1000`.

Run the following command and replace `<tag>` with the image variant you want to run:

```bash
$ docker volume create gitea_data
$ docker volume create gitea_config
$ docker run -d --name gitea \
    -p 3000:3000 -p 2222:2222 \
    -v gitea_data:/var/lib/gitea \
    -v gitea_config:/etc/gitea \
    -e INSTALL_LOCK=true \
    -e SECRET_KEY="$(openssl rand -hex 32)" \
    dhi.io/gitea:<tag>
```

This starts Gitea with SQLite (the default database), skips the interactive web installer (`INSTALL_LOCK=true`), and
serves the web UI on port 3000 and the builtin SSH server on port 2222. Named volumes created by Docker are
automatically populated from the image's `/var/lib/gitea` and `/etc/gitea` directories on first use, so they inherit the
correct `1000:1000` ownership. If you bind-mount host directories instead, `chown` them to `1000:1000` before starting
the container, or the `git` user won't be able to write to them.

To check the installed version or inspect the `gitea` binary's help output without starting the web server, override the
entry point:

```bash
$ docker run --rm --entrypoint /usr/local/bin/gitea dhi.io/gitea:<tag> --version
$ docker run --rm --entrypoint /usr/local/bin/gitea dhi.io/gitea:<tag> --help
```

### Environment variables

These variables are only applied when `/etc/gitea/app.ini` doesn't already exist, that is, on the container's first run.
After that, edit `app.ini` directly or use `GITEA__SECTION__KEY` variables (see below), which are re-applied on every
start.

| Variable               | Description                                                           | Default                        | Required                         |
| ---------------------- | --------------------------------------------------------------------- | ------------------------------ | -------------------------------- |
| `APP_NAME`             | Instance display name                                                 | `Gitea: Git with a cup of tea` | No                               |
| `RUN_MODE`             | Application run mode (`dev`, `prod`)                                  | `prod`                         | No                               |
| `SSH_DOMAIN`           | Domain used to build SSH clone URLs shown in the UI                   | `localhost`                    | No                               |
| `HTTP_PORT`            | Port the web server listens on inside the container                   | `3000`                         | No                               |
| `ROOT_URL`             | Public base URL used when generating links                            | (empty)                        | Recommended in production        |
| `DISABLE_SSH`          | Disable SSH access entirely                                           | `false`                        | No                               |
| `SSH_PORT`             | Port advertised in SSH clone URLs                                     | `2222`                         | No                               |
| `SSH_LISTEN_PORT`      | Port the builtin SSH server actually binds to                         | Value of `SSH_PORT`            | No                               |
| `LFS_START_SERVER`     | Enable Git LFS support                                                | (unset)                        | No                               |
| `DB_TYPE`              | Database backend: `sqlite3`, `postgres`, or `mysql`                   | `sqlite3`                      | No                               |
| `DB_HOST`              | Database host and port                                                | `localhost:3306`               | Yes, for `postgres` or `mysql`   |
| `DB_NAME`              | Database name                                                         | `gitea`                        | Yes, for `postgres` or `mysql`   |
| `DB_USER`              | Database user                                                         | `root`                         | Yes, for `postgres` or `mysql`   |
| `DB_PASSWD`            | Database password                                                     | (empty)                        | Yes, for `postgres` or `mysql`   |
| `INSTALL_LOCK`         | Skip the interactive web installer and use the generated config as-is | `false`                        | Recommended for unattended setup |
| `DISABLE_REGISTRATION` | Disable public self-registration                                      | `false`                        | No                               |
| `REQUIRE_SIGNIN_VIEW`  | Require sign-in to view any page                                      | `false`                        | No                               |
| `SECRET_KEY`           | Secret key used to encrypt sensitive data                             | (empty)                        | Yes, when `INSTALL_LOCK=true`    |

Setting `SECRET_KEY` without `INSTALL_LOCK` automatically enables `INSTALL_LOCK=true`. These variables mirror the
upstream rootless image's first-run bootstrap; for every other setting, see the
[Gitea configuration cheat sheet](https://docs.gitea.com/administration/config-cheat-sheet).

For any setting not covered above, set `GITEA__<SECTION>__<KEY>=<value>` (matching the `[section]` and `KEY` in
`app.ini`) and it's applied on every container start via `environment-to-ini`, for example
`GITEA__database__DB_TYPE=postgres`.

## Common gitea use cases

### Run with PostgreSQL using Docker Compose

For anything beyond light, single-user use, run Gitea against PostgreSQL instead of SQLite:

```yaml
services:
  gitea:
    image: dhi.io/gitea:<tag>
    ports:
      - "3000:3000"
      - "2222:2222"
    environment:
      GITEA__database__DB_TYPE: postgres
      GITEA__database__HOST: db:5432
      GITEA__database__NAME: gitea
      GITEA__database__USER: gitea
      GITEA__database__PASSWD: gitea
      INSTALL_LOCK: "true"
      SECRET_KEY: change-me-to-a-random-string
    volumes:
      - gitea_data:/var/lib/gitea
      - gitea_config:/etc/gitea
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/healthz"]
      interval: 30s
      timeout: 5s
      retries: 3
    depends_on:
      - db

  db:
    image: dhi.io/postgres:<tag>
    environment:
      POSTGRES_DB: gitea
      POSTGRES_USER: gitea
      POSTGRES_PASSWORD: gitea
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  gitea_data: {}
  gitea_config: {}
  postgres_data: {}
```

### Use Git over SSH

The rootless image only supports Gitea's builtin SSH server on port 2222; there's no `sshd` to configure separately.
Publish port 2222, add a public key to a user account through the web UI or the admin CLI (see below), then clone over
SSH:

```bash
$ git clone ssh://git@localhost:2222/<owner>/<repo>.git
```

If you front the container with a reverse proxy or NAT that advertises a different SSH port than the one the builtin
server binds to inside the container, set `SSH_PORT` (used to build clone URLs in the UI) and `SSH_LISTEN_PORT` (the
actual bind port) independently:

```bash
$ docker run -d --name gitea \
    -p 3000:3000 -p 22:2222 \
    -v gitea_data:/var/lib/gitea \
    -v gitea_config:/etc/gitea \
    -e SSH_DOMAIN=git.example.com \
    -e SSH_PORT=22 \
    -e SSH_LISTEN_PORT=2222 \
    dhi.io/gitea:<tag>
```

### Manage Gitea with the admin CLI

The `gitea` wrapper on `PATH` automatically points the CLI at the running instance's `app.ini`, so admin commands work
directly with `docker exec`:

```bash
$ docker exec -u git gitea gitea admin user create \
    --username admin --password 'change-me' --email admin@example.com --admin
```

### Advanced configuration

For advanced setups, see the upstream Gitea documentation:

- [Gitea Actions and act_runner](https://docs.gitea.com/usage/actions/overview) for CI/CD pipelines that can reuse
  GitHub Actions workflows.
- [Git LFS](https://docs.gitea.com/administration/git-lfs-setup) for large file storage, enabled with
  `LFS_START_SERVER=true`.
- [Repository mirroring](https://docs.gitea.com/usage/repo-mirror) for pull and push mirrors and replication between
  Gitea instances.
- [Customizing Gitea](https://docs.gitea.com/administration/customizing-gitea) for custom templates, themes, and public
  assets, mounted under `/var/lib/gitea/custom`.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  > **Note:** Unlike most DHI runtime images, this image includes `bash` because the upstream rootless entrypoint
  > scripts require it. It still has no package manager.

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | Runtime images run as the `git` user (UID/GID 1000). Ensure `/var/lib/gitea` and `/etc/gitea` (or your bind mounts) are writable by that user.                                                                                                                                                                               |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| Shell              | Most non-dev DHI images omit a shell; this image includes `bash` for the rootless entrypoint scripts, but still has no package manager.                                                                                                                                                                                      |

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

This runtime image includes `bash` for the rootless entrypoint scripts, but not a broader debug toolkit. Prefer
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach common debugging tools in an ephemeral
layer.

### Permissions

Runtime images run as the `git` user (UID/GID 1000). Ensure `/var/lib/gitea` and `/etc/gitea` (or your bind mounts) are
writable by that user.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
