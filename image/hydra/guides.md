## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/hydra:<tag>`
- Mirrored image: `<your-namespace>/dhi-hydra:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Ory Hydra is an OAuth 2.0 server and OpenID Connect provider. This image is the hardened stand-in for `oryd/hydra`.
Configuration and advanced usage are documented upstream at https://www.ory.com/docs/hydra.

The container entrypoint is `hydra` and the default command is `serve all`, the same as upstream. Port 4444 serves the
public OAuth 2.0 and OpenID Connect endpoints and port 4445 serves the admin API. The runtime image runs as numeric user
65532, the uid of upstream's `nonroot` user.

Hydra reads its configuration from environment variables or from a file passed with `-c`. Every `serve` example sets the
database (`DSN`), the issuer URL and the system secret, as environment variables or in `hydra.yml`. Replace the example
secrets with your own.

## Start a Hydra image

### Check the version

```bash
docker run --rm dhi.io/hydra:<tag> version
```

The command prints the `Version`, `Git Hash` and `Build Time` lines and exits.

### Run Hydra with an in-memory database

`DSN=memory` keeps everything in an in-memory SQLite database and runs the migrations at startup; Hydra logs that the
data is lost when it terminates, so use this for trying Hydra out. `--dev` allows the plain HTTP issuer. The ports bind
to loopback because the admin API on port 4445 has no access control of its own.

```bash
docker run -d --name hydra \
  -p 127.0.0.1:4444:4444 -p 127.0.0.1:4445:4445 \
  -e DSN=memory \
  -e URLS_SELF_ISSUER=http://127.0.0.1:4444 \
  -e SECRETS_SYSTEM=change-this-system-secret \
  dhi.io/hydra:<tag> serve all --dev
```

Check readiness and discovery from the host:

```bash
curl http://127.0.0.1:4445/health/ready
curl http://127.0.0.1:4444/.well-known/openid-configuration
```

`/health/ready` returns `{"status":"ok"}`, and the discovery document reports `"issuer":"http://127.0.0.1:4444"`.

Create a client and request a token with the Hydra CLI inside the running container:

```bash
docker exec hydra hydra create client --endpoint http://127.0.0.1:4445/ --format json \
  --grant-type client_credentials
docker exec hydra hydra perform client-credentials --endpoint http://127.0.0.1:4444/ \
  --client-id <client_id> --client-secret <client_secret>
```

The first command prints the new client as JSON, including `client_id` and `client_secret`. The second prints an
`ACCESS TOKEN` line with an `ory_at_` token. Stop the container with `docker rm -f hydra`.

## Common Hydra use cases

### Persist data in SQLite with the upstream quickstart configuration

This follows upstream's `quickstart.yml`: a migration run, then the server, both reading the same `hydra.yml` and the
same SQLite file. The `hydra.yml` below is a shortened copy of upstream's `contrib/quickstart/5-min/hydra.yml`, and
upstream marks the quickstart setup as for demonstration purposes only.

Create the configuration and a data directory the runtime user can write:

```bash
mkdir -p hydra-config hydra-sqlite
sudo chown 65532:65532 hydra-sqlite
cat > hydra-config/hydra.yml <<'YAML'
serve:
  cookies:
    same_site_mode: Lax

urls:
  self:
    issuer: http://127.0.0.1:4444
  consent: http://127.0.0.1:3000/consent
  login: http://127.0.0.1:3000/login
  logout: http://127.0.0.1:3000/logout

secrets:
  system:
    - change-this-system-secret
YAML
```

Run the migrations, then start the server:

```bash
docker run --rm \
  -v "$PWD/hydra-sqlite:/mnt/sqlite" -v "$PWD/hydra-config:/etc/config/hydra" \
  -e 'DSN=sqlite:///mnt/sqlite/db.sqlite?_fk=true&mode=rwc' \
  dhi.io/hydra:<tag> migrate -c /etc/config/hydra/hydra.yml sql up -e --yes

docker run -d --name hydra \
  -p 127.0.0.1:4444:4444 -p 127.0.0.1:4445:4445 \
  -v "$PWD/hydra-sqlite:/mnt/sqlite" -v "$PWD/hydra-config:/etc/config/hydra" \
  -e 'DSN=sqlite:///mnt/sqlite/db.sqlite?_fk=true&mode=rwc' \
  dhi.io/hydra:<tag> serve -c /etc/config/hydra/hydra.yml all --dev
```

The migration run ends with `Successfully applied migrations!`. `hydra migrate sql status -e` with the same `DSN` lists
every migration as `Applied`. Clients created against this server survive a container restart.

For production, use PostgreSQL: set `DSN=postgres://<user>:<password>@<host>:5432/<database>?sslmode=disable` (or your
TLS settings) and run the same `migrate sql up -e --yes` step before `serve all`. MySQL and CockroachDB are described at
https://www.ory.com/docs/hydra/self-hosted/dependencies-environment.

### Keep signing keys in a hardware security module

To keep the signing keys in a hardware security module through PKCS#11, follow
https://www.ory.com/docs/hydra/self-hosted/hsm-support with a PKCS#11 library built for the image's C library: glibc for
the Debian variants, musl for the Alpine variants.

## Non-hardened images vs. Docker Hardened Images

- The runtime image has no shell and no package manager. Upstream's Alpine image ships BusyBox `sh`. Use the `dev`
  variant or Docker Debug when you need a shell.
- The user is the numeric uid 65532. Upstream's default image sets the user by the name `nonroot`, which has the same
  uid.
- The image exposes ports 4444 and 4445, like upstream's `-distroless` image. Upstream's default image exposes none.
- The image sets `SQA_OPT_OUT=true`, so Hydra sends Ory one startup message that records the opt-out and no usage data
  after it. Upstream's image sends usage data by default. Set `SQA_OPT_OUT=false` to turn it back on.
- The image is published for `linux/amd64` and `linux/arm64`. Upstream also publishes `linux/arm/v6` and `linux/arm/v7`.
- SQLite support and HSM support are compiled in on both platforms. Upstream's default image has both on amd64; on arm64
  it has SQLite without HSM support, and its `-distroless` image has neither. This image has no `-distroless` tag.
- Tags carry no `v` prefix: `dhi.io/hydra:26`, `dhi.io/hydra:26.2` and `dhi.io/hydra:26.2.0` correspond to
  `oryd/hydra:v26`, `oryd/hydra:v26.2` and `oryd/hydra:v26.2.0`.
- FIPS variants: the FIPS claim covers the Go crypto in `hydra` and the OpenSSL provider. Signing done inside a hardware
  security module happens outside it. Hydra does not work under `GODEBUG=fips140=only`: it encrypts its signing keys
  with AES-GCM through Go's `cipher.NewGCM`, which that mode refuses, so it cannot create keys or issue tokens. Leave
  `GODEBUG` unset; the FIPS binary already runs with `fips140=on`.

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
