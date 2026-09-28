## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a director

The director listens on port 1234 and keeps runs in memory until you point it at MongoDB. The API has no authentication
of its own, so bind it to loopback while you try it out.

```
docker run -d --name sorry-cypress-director -p 127.0.0.1:1234:1234 dhi.io/sorry-cypress-director:<tag>
```

Check that it is up.

```
curl http://127.0.0.1:1234/ping
```

### Record a Cypress run

Cypress records to the director when `CYPRESS_API_URL` names it. A recorded run needs a record key and a CI build id.
Machines that send the same CI build id join the same run and split its spec files between them.

```
CYPRESS_API_URL=http://127.0.0.1:1234/ npx cypress run --record --key my-key --parallel --ci-build-id build-1
```

### Restrict record keys

The director accepts any record key by default. Set `ALLOWED_KEYS` to a comma separated list and it answers `403` to
runs that carry any other key.

```
docker run -d --name sorry-cypress-director -p 127.0.0.1:1234:1234 \
  -e ALLOWED_KEYS=my-key,other-key \
  dhi.io/sorry-cypress-director:<tag>
```

### Store runs in MongoDB

Runs kept in memory are lost when the container stops. Set the MongoDB execution driver to keep them in a database that
the upstream `agoldis/sorry-cypress-api` and `agoldis/sorry-cypress-dashboard` images can read.

```yaml
services:
  mongo:
    image: mongo:8.0
    volumes:
      - mongo-data:/data/db
  director:
    image: dhi.io/sorry-cypress-director:<tag>
    ports:
      - "127.0.0.1:1234:1234"
    environment:
      EXECUTION_DRIVER: ../execution/mongo/driver
      MONGODB_URI: mongodb://mongo:27017
      MONGODB_DATABASE: sorry-cypress
      DASHBOARD_URL: http://localhost:8080
      ALLOWED_KEYS: my-key
    depends_on:
      - mongo
volumes:
  mongo-data:
```

`GET /health-check-db` answers `200` once the director can reach MongoDB, so use it as the readiness probe.

### Configuration

The director reads its settings from environment variables such as `PORT`, `DASHBOARD_URL`, `EXECUTION_DRIVER`,
`MONGODB_URI`, `SCREENSHOTS_DRIVER` and `INACTIVITY_TIMEOUT_SECONDS`. The full list, including the S3, MinIO, Azure Blob
Storage and Google Cloud Storage screenshot drivers, is in the
[upstream documentation](https://docs.sorry-cypress.dev/configuration/director-configuration).

## Non-hardened images vs. Docker Hardened Images

The default command is `/usr/local/bin/sorry-cypress-director`, a launcher that starts the director under `node`
directly. Upstream runs it through `pm2-runtime`, which is not shipped. The entrypoint stays `tini --` as upstream, so
SIGTERM reaches the process and the container stops cleanly. pm2-runtime also restarted the director after an unhandled
error, and this image exits with code 1 instead, so give the container a restart policy (`restart: unless-stopped` in
compose, the pod restart policy in Kubernetes).

The container runs as uid 65532 instead of the `node` user.

The application lives in `/usr/lib/nodejs/sorry-cypress-director`. `/app` is a symlink to that directory and stays the
working directory, so `node packages/director/dist` from `/app` works as it does upstream.

The runtime image has no shell and no package manager. Use `dhi.io/sorry-cypress-director:<tag>-dev` or Docker Debug
when you need them.

The FIPS variants run Node.js with the OpenSSL FIPS provider, so TLS and `crypto` calls go through the validated module.
The director computes run ids and screenshot keys with the pure JavaScript `md5` package, which does not use the module
and keeps working in FIPS mode. MongoDB authentication has to use SCRAM-SHA-256 on the FIPS variants (set
`MONGODB_AUTH_MECHANISM=SCRAM-SHA-256`), because SCRAM-SHA-1 hashes the password with MD5 through Node's `crypto` and
fails there.

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
