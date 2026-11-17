## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Prerequisites

Codecov Frontend is the web application of a self-hosted Codecov deployment. It serves static files only; every page it
renders calls the Codecov API, so a working deployment also needs the Codecov API, worker and gateway services and their
data stores. The [Codecov self-hosted repository](https://github.com/codecov/self-hosted) carries the reference compose
file this image follows, and the [Codecov configuration reference](https://docs.codecov.com/docs/configuration)
documents the deployment.

## Start a Codecov Frontend instance

The built application points at the hosted Codecov service. At container start the image rewrites the API and web hosts
in the JavaScript bundles from `CODECOV_API_HOST`, `CODECOV_BASE_HOST` and `CODECOV_SCHEME`, renders the nginx
configuration and starts nginx on port 8080. Set the hosts to the address your users reach the Codecov gateway at:

```bash
$ docker run -d --name codecov-frontend -p 127.0.0.1:8080:8080 \
    -e CODECOV_BASE_HOST=codecov.example.com \
    -e CODECOV_API_HOST=codecov.example.com \
    dhi.io/codecov-frontend:<tag>
```

Replace `<tag>` with the tag of the variant you want to run. The port is bound to the loopback interface above because
the frontend is meant to sit behind the Codecov gateway; expose it directly only on a trusted network.
`GET http://localhost:8080/frontend_health` answers HTTP 200 with the packaged release as its body once nginx is
serving, and `GET /` serves the application.

The frontend service of the upstream compose file runs unchanged with the image reference swapped (its `CODECOV_IA_HOST`
line is not read by the frontend and is left out here):

```yaml
services:
  frontend:
    image: dhi.io/codecov-frontend:<tag>
    environment:
      - CODECOV_BASE_HOST=localhost:8080
      - CODECOV_API_HOST=localhost:8080
      - CODECOV_SCHEME=http
    ports:
      - "8080"
```

### Environment variables

The start script reads these variables. Every substitution is applied to the JavaScript bundles at container start, so a
change needs a container restart.

| Variable                         | Description                                                             | Default          |
| -------------------------------- | ----------------------------------------------------------------------- | ---------------- |
| `CODECOV_BASE_HOST`              | Host, with an optional port, the Codecov web application is reached at. | `codecov.io`     |
| `CODECOV_API_HOST`               | Host, with an optional port, the Codecov API is reached at.             | `api.codecov.io` |
| `CODECOV_SCHEME`                 | Scheme written in front of both hosts.                                  | `https`          |
| `CODECOV_API_HOST_SEARCH`        | API host the built bundles carry and the rewrite looks for.             | `api.codecov.io` |
| `CODECOV_HOST_SEARCH`            | Web host the built bundles carry and the rewrite looks for.             | `codecov.io`     |
| `CODECOV_SCHEME_SEARCH`          | Scheme the built bundles carry and the rewrite looks for.               | `https`          |
| `CODECOV_GHE_HOST`               | GitHub Enterprise Server host; written into the bundles when set.       | unset            |
| `CODECOV_GHE_SCHEME`             | Scheme for `CODECOV_GHE_HOST`.                                          | `https`          |
| `CODECOV_GLE_HOST`               | GitLab self-managed host; written into the bundles when set.            | unset            |
| `CODECOV_GLE_SCHEME`             | Scheme for `CODECOV_GLE_HOST`.                                          | `https`          |
| `CODECOV_BBS_HOST`               | Bitbucket Server host; written into the bundles when set.               | unset            |
| `CODECOV_BBS_SCHEME`             | Scheme for `CODECOV_BBS_HOST`.                                          | `https`          |
| `CODECOV_FRONTEND_IPV6_DISABLED` | When set to any value, nginx listens on IPv4 only.                      | unset            |
| `BUILD_VERSION`                  | First word of the `/frontend_health` response.                          | the release      |
| `BUILD_ID`                       | Second word of the `/frontend_health` response.                         | unset            |

## Common Codecov Frontend use cases

### Connect a self-managed git provider

Codecov supports GitHub Enterprise Server, GitLab self-managed and Bitbucket Server next to the hosted providers. Set
the matching host so the login and repository links in the application point at your server:

```bash
$ docker run -d --name codecov-frontend -p 127.0.0.1:8080:8080 \
    -e CODECOV_BASE_HOST=codecov.example.com \
    -e CODECOV_API_HOST=codecov.example.com \
    -e CODECOV_GHE_HOST=github.example.com \
    dhi.io/codecov-frontend:<tag>
```

The container logs `Replacing GHE https://github.example.com` before nginx starts. The API service needs the matching
provider configuration from the Codecov configuration reference.

### Run on IPv4-only hosts

On a host or cluster without IPv6, nginx fails to bind its `[::]:8080` listener. Disable it:

```bash
$ docker run -d --name codecov-frontend -p 127.0.0.1:8080:8080 \
    -e CODECOV_BASE_HOST=codecov.example.com \
    -e CODECOV_API_HOST=codecov.example.com \
    -e CODECOV_FRONTEND_IPV6_DISABLED=1 \
    dhi.io/codecov-frontend:<tag>
```

The container logs `Codecov frontend ipv6 disabled` and serves on IPv4 only.

### Health checks

`/frontend_health` returns HTTP 200 with the release as its body. Runtime images carry no `curl`, so probe from the
orchestrator:

```yaml
readinessProbe:
  httpGet:
    path: /frontend_health
    port: 8080
  periodSeconds: 5
```

### Run a command in the image

Passing a command to the image runs it instead of starting nginx, the same as the upstream image:

```bash
$ docker run --rm dhi.io/codecov-frontend:<tag> nginx -v
```

## Non-hardened images vs. Docker Hardened Images

- The application is installed from the `dhi/pkg-codecov-frontend` package at `/usr/share/codecov-frontend/gazebo`, and
  the upstream start script as `/usr/bin/codecov-frontend`. Upstream serves `/var/www/app/gazebo` and starts through
  `/usr/bin/start-nginx`; both paths are kept as symlinks, the image's entrypoint is `/usr/local/bin/codecov-frontend`
  and the work directory is the upstream path `/var/www/app`.
- The image runs as uid 65532; upstream runs as the `codecov` user (uid 1000). The `assets` directory of the application
  is the only path the runtime user owns, because the start script rewrites the bundles in place.
- The nginx templates the start script renders live at `/etc/codecov-frontend/nginx.conf.template` and
  `/etc/codecov-frontend/nginx-no-ipv6.conf.template` instead of `/etc/nginx`, and the rendered configuration and the
  pid file are written to `/tmp`. Extra nginx configuration is included from `/etc/codecov-frontend/conf.d/*.conf`
  instead of `/etc/nginx/conf.d`, which the Debian nginx package populates with its own default server.
- The prebuilt Codecov uploader binaries the upstream image serves under `/uploader` are not shipped; those paths answer
  HTTP 404. The uploader is deprecated upstream in favour of the Codecov CLI, and prebuilt binaries cannot be built from
  source or covered by the SBOM.
- Upstream publishes the channel tags `latest-stable`, `latest-calver` and `rolling` next to the release tag; this image
  publishes release tags only (`26.7.6`, `26.7`, `26` and their distro-suffixed forms), so a compose file that pins
  `latest-calver` moves to a release tag.
- The runtime image ships `bash`, `sed` and `envsubst` on Debian and BusyBox and `envsubst` on Alpine because the
  upstream start script needs them; it ships no other shell tooling, no `curl` and no package manager.

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
