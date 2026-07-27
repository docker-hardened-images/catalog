## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/gitlab-shell:<tag>`
- Mirrored image: `<your-namespace>/dhi-gitlab-shell:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included

This image installs the GitLab Shell binaries from the Docker-built `gitlab-shell` package:

- `gitlab-sshd` — the standalone Go SSH server that terminates Git-over-SSH sessions (the image entry point)
- `gitlab-shell` — the per-session command handler that authorizes and routes Git operations
- `gitlab-shell-authorized-keys-check` — resolves an SSH key to a GitLab user (OpenSSH `AuthorizedKeysCommand` helper)
- `gitlab-shell-authorized-principals-check` — resolves SSH certificate principals to a GitLab user
- `gitlab-shell-check` — diagnostic that verifies connectivity to the GitLab internal API

The start script is installed at `/scripts/start-gitlab-sshd` and is the image entry point.

## Run the container

GitLab Shell is part of a Cloud Native GitLab (CNG) deployment. `gitlab-sshd` terminates Git-over-SSH connections and
authenticates them against the GitLab internal API, so it shares a secret and a `gitlab_url` with the rest of the GitLab
stack. For a complete GitLab deployment, use the [GitLab Helm chart](https://docs.gitlab.com/charts/) or the
[CNG Docker Compose](https://gitlab.com/gitlab-org/build/CNG/-/blob/master/docker-compose.yml) setup.

The entry point (`/scripts/start-gitlab-sshd`) launches `gitlab-sshd`, which listens for SSH on `2222` and serves
Prometheus metrics and health checks over HTTP on `9122`. On startup the script generates SSH host keys under
`/srv/gitlab-shell/hostkeys` and writes an ephemeral shared secret when none are mounted, so the daemon boots out of the
box for evaluation. For any real deployment, mount your own configuration, host keys, and secret (see
[Configuration](#configuration)).

> **Note:** This image runs `gitlab-sshd` only (the Cloud Native Go SSH server), not the OpenSSH-based mode. Because the
> binaries are built pure-Go with CGO disabled (required for the hardened and FIPS builds), GSSAPI/Kerberos SSH
> authentication — which upstream enables only in CGO builds — is not available. Use SSH key or certificate
> authentication instead.

### Check the version

Use the single-dash `-version` flag (it must be the only argument):

```bash
$ docker run --rm --entrypoint gitlab-sshd dhi.io/gitlab-shell:<tag> -version
```

### Health checks

`gitlab-sshd` serves Prometheus metrics and a health endpoint over HTTP on port `9122`. The image ships a
`/scripts/healthcheck` helper that probes that endpoint; wire it into a container `HEALTHCHECK` or a Kubernetes
liveness/readiness probe. For example:

```bash
$ docker run -d --health-cmd /scripts/healthcheck \
  -p 2222:2222 -p 9122:9122 dhi.io/gitlab-shell:<tag>
```

## Configuration

`gitlab-sshd` reads its configuration from a directory (default `/srv/gitlab-shell`) that contains a `config.yml`, the
SSH host keys, and the shared secret file. The image ships a default `config.yml`; mount your own to point the daemon at
your GitLab instance. At minimum, set `gitlab_url` and provide a real `secret` (or `secret_file`). See the upstream
[`config.yml.example`](https://gitlab.com/gitlab-org/gitlab-shell/-/blob/main/config.yml.example) for the full
reference.

| Path / Variable                          | Purpose                                                                                           |
| :--------------------------------------- | :------------------------------------------------------------------------------------------------ |
| `/srv/gitlab-shell/config.yml`           | GitLab Shell configuration (`gitlab_url`, `sshd.listen`, `sshd.web_listen`). Mount your own.      |
| `/srv/gitlab-shell/.gitlab_shell_secret` | Shared secret used to authenticate to the GitLab internal API. Mount your instance's real secret. |
| `/srv/gitlab-shell/hostkeys`             | SSH host keys. Mount your own; otherwise the entry point generates ephemeral keys at startup.     |
| `GITLAB_SHELL_DIR`                       | Configuration directory passed to `gitlab-sshd -config-dir` (default `/srv/gitlab-shell`).        |
| `GITLAB_SHELL_HOST_KEY_DIR`              | Directory for generated SSH host keys (default `${GITLAB_SHELL_DIR}/hostkeys`).                   |
| `GITLAB_SHELL_SECRET_FILE`               | Path to the shared secret file (default `${GITLAB_SHELL_DIR}/.gitlab_shell_secret`).              |

To run against your own GitLab instance, mount a directory containing your `config.yml` (with `gitlab_url` and a real
`secret_file`) and your SSH host keys over `/srv/gitlab-shell`:

```bash
$ docker run -d --name gitlab-shell \
  -p 2222:2222 -p 9122:9122 \
  -v /path/to/gitlab-shell-config:/srv/gitlab-shell \
  dhi.io/gitlab-shell:<tag>
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
