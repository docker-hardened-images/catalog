## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/authelia:4`
- Mirrored image: `<your-namespace>/dhi-authelia:4`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Commands below use a detailed tag such as `4.39.28-debian13`. The short tag `4` tracks that 4.x runtime line.
Configuration and deployment guidance is at https://www.authelia.com.

## Start an Authelia image

The runtime image runs `/usr/bin/authelia` as UID 65532 and listens on port 9091. `X_AUTHELIA_CONFIG` is
`/config/configuration.yml`. Mount a directory at `/config` that this user can read and write. Authelia creates
`/config/db.sqlite3` and `/config/notification.txt` in that directory.

Create `config/` and the two files below, then give the directory to UID 65532 and GID 65532. Write the files first.
Mode `0644` is enough for the runtime user to read them.

```bash
mkdir -p config
```

`config/configuration.yml`:

```yaml
server:
  address: 'tcp://:9091'

authentication_backend:
  file:
    path: /config/users_database.yml

access_control:
  default_policy: one_factor

session:
  secret: factory-session-secret-not-real
  cookies:
    - name: authelia_session
      domain: example.com
      authelia_url: https://auth.example.com
      expiration: 1h
      inactivity: 5m

identity_validation:
  reset_password:
    jwt_secret: factory-jwt-secret-not-real

storage:
  encryption_key: factory-storage-encryption-key-not-real
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt
```

`config/users_database.yml`:

```yaml
users:
  authelia:
    disabled: false
    displayname: Authelia User
    password: "$argon2id$v=19$m=65536,t=3,p=4$NsoEeIFwyW9UdcGgK4AQEA$bPkyy9I9gJvAPdFoTx2elhb+xcOix1P+Gj1mZWKR7HM"
    email: authelia@example.com
    groups: []
```

The password value is an Argon2id digest of `factory-test-password`. The secrets above are placeholders. This sample
sets `access_control.default_policy` to `one_factor` for every request. Replace the policy and the secrets before
production use. The health check does not sign in.

```bash
docker run --rm --entrypoint /bin/bash \
  -v "$(pwd)/config:/config" \
  dhi.io/authelia:4.39.28-dev \
  -lc 'chown 65532:65532 /config && chmod 0770 /config'
```

Start the server:

```bash
docker run -d --name authelia -p 9091:9091 \
  -v "$(pwd)/config:/config" \
  dhi.io/authelia:4.39.28-debian13
```

The log includes `Listening for non-TLS connections on '[::]:9091'`. After that line, check health and the login portal:

```bash
curl -fsS http://127.0.0.1:9091/api/health
```

```bash
curl -fsS http://127.0.0.1:9091/ | grep 'id="root"'
```

Health returns `{"status":"OK"}`. The portal response is HTML containing `id="root"`.

Print the version:

```bash
docker run --rm dhi.io/authelia:4.39.28-debian13 --version
```

The command prints `authelia version v4.39.28`.

## Common Authelia use cases

### Generate a password digest

```bash
docker run --rm dhi.io/authelia:4.39.28-debian13 crypto hash generate argon2 --password factory-test-password --no-confirm
```

The output line starts with `Digest: $argon2id$`. Use that digest as a user's `password` in `users_database.yml`. Each
run uses a new salt.

### Upstream entrypoint

The `4.39.28-debian13-compat` tag uses `/app/entrypoint.sh`. The container user is still 65532, so the script does not
take its root branch. It executes Authelia directly.

A first argument other than `--config` is the program to execute. Print the version by passing `authelia`:

```bash
docker run --rm dhi.io/authelia:4.39.28-debian13-compat authelia --version
```

`PUID` and `PGID` are read only when that script runs as root (`--user 0`) and the first argument is empty or
`--config`. The default user is 65532, so the version command above does not take that branch. The root branch runs
`/usr/bin/su-exec`, a link to `gosu`, and starts Authelia as `PUID:PGID`. Both variables default to `0`.

Compat tags do not include upstream's `/app/healthcheck.sh` or `/app/.healthcheck.env`. Those files call `wget`, which
the Debian compat image does not ship. Check `http://127.0.0.1:9091/api/health` instead of `/app/healthcheck.sh`.

```bash
docker run --rm --user 0 --entrypoint /usr/bin/su-exec \
  dhi.io/authelia:4.39.28-debian13-compat 65532:65532 authelia --version
```

The command prints `authelia version v4.39.28`.

### Configuration directory

`/config` in the image is mode `0770`, UID 65532, GID 65532. The dev tag runs as root and includes a shell. The
directory ownership stays 65532:

```bash
docker run --rm --entrypoint /bin/bash dhi.io/authelia:4.39.28-dev -lc 'ls -ldn /config'
```

## Non-hardened images vs. Docker Hardened Images

Upstream `authelia/authelia` starts `/app/entrypoint.sh`. This image's runtime entrypoint is `/usr/bin/authelia`, so
arguments such as `--version` are passed to Authelia. Use `dhi.io/authelia:4.39.28-debian13-compat` when you need the
upstream script, and pass `authelia` as the program name. `PUID` and `PGID` apply only with `--user 0` on that script.
The runtime and compatibility images default to UID 65532. A bind-mounted `/config` must be writable by that user. The
runtime image has no shell. Use a `dev` tag to inspect files.

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
