## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/gitlab-sidekiq:<tag>`
- Mirrored image: `<your-namespace>/dhi-gitlab-sidekiq:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a GitLab Sidekiq instance

GitLab Sidekiq is the background job processor component of Cloud Native GitLab (CNG). It runs the full GitLab Rails
application and requires external PostgreSQL, Redis, and Gitaly services. It is not a standalone service: for a complete
GitLab deployment, use the GitLab Helm chart or Docker Compose with all required services.

### Check the version

```bash
$ docker run --rm dhi.io/gitlab-sidekiq:<tag> cat /srv/gitlab/VERSION
```

### With Docker Compose

A complete CNG deployment requires multiple services. See the
[Cloud Native GitLab documentation](https://docs.gitlab.com/charts/) for Helm chart deployment, or the
[CNG Docker Compose](https://gitlab.com/gitlab-org/build/CNG/-/blob/master/docker-compose.yml) for a development setup.

## Logging behavior

Upstream `gitlab-sidekiq` defaults to `USE_GITLAB_LOGGER=1`, which forwards logs through the `gitlab-logger` binary
shipped by the `gitlab-base` image. Docker Hardened Images do not ship that binary, so this image defaults to
`USE_GITLAB_LOGGER=0`, which tails the log files under `/var/log/gitlab` with `xtail` instead. Application logs are
unaffected; only the log-forwarding mechanism differs. Do not set `USE_GITLAB_LOGGER=1` on this image unless you provide
your own `gitlab-logger` binary.

Alpine has no `xtail` package, so on the Alpine variants `process-wrapper` falls back to `tail -f` over the files
present at start; log files a job creates later are not picked up by the container's stdout.

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened GitLab Sidekiq image is a drop-in replacement for the upstream
`registry.gitlab.com/gitlab-org/build/cng/gitlab-sidekiq-ce` image. It ships the same Rails tree under `/srv/gitlab`,
the full upstream `/scripts` set (including `wait-for-deps` and `db-migrate`, which the GitLab Helm chart runs from this
image), and accepts the same `CONFIG_TEMPLATE_DIRECTORY` / `CONFIG_DIRECTORY` configuration. The notable differences
are:

- Two OS bases are published, Debian 13 and Alpine 3.24; upstream is Debian only.
- No `tini`. The entry point renders the configuration and executes the command directly, so `USE_TINI` has no effect.
  `process-wrapper` still `exec`s `sidekiq-cluster`, which becomes PID 1. Use `docker run --init` if you need an init
  process outside Kubernetes.
- No `gitlab-logger`; see [Logging behavior](#logging-behavior).
- No `gomplate`, so `set-config` renders only `.erb` templates; `.tpl` templates in `CONFIG_TEMPLATE_DIRECTORY` are
  skipped.
- Not shipped: `gm` (GraphicsMagick). Jobs that shell out to it fail in this image.
- No precompiled bootsnap cache. Upstream ships one; here bootsnap writes its cache to `/srv/gitlab/bootsnap` on first
  boot, so the first start of a fresh container takes longer. Mount a volume there to keep it across restarts.
- The Rails tree is root-owned. The paths the workers write are owned by the `git` user (UID 1000): `config/`, `tmp/`,
  `bootsnap/`, `builds/`, `public/uploads/`, `shared/artifacts/`, `shared/pages/` under `/srv/gitlab`, plus
  `/var/opt/gitlab`, `/var/log/gitlab` and `/home/git`.
- The runtime image has no package manager. Besides `bash`, `coreutils`, `findutils`, `grep`, `sed` and `awk` it carries
  what the workers shell out to: `git`, `openssh-client`, `psql`, `exiftool`, `perl`, `procps`, `gzip` and (Debian only)
  `xtail`. For anything else, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) or the `dev`
  variant.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a package manager. This image ships `bash` because its entry point requires one, see
    [No shell](#no-shell)
  - Contain only the minimal set of libraries needed to run the app

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                               |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the git user. Ensure that necessary files and directories are accessible to that user.                                                                                              |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                             |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                           |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. This image is an exception and ships `bash` for its entry point. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |
| Privileged ports   | Docker Hardened Images run as a nonroot user by default and cannot bind to privileged ports (below 1024). Update your configuration to use a port above 1024.                                                                                |

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

The hardened images intended for runtime don't contain tools for debugging. This image ships `bash` for its entry point,
but nothing else useful for debugging is present. The recommended method for debugging applications built with Docker
Hardened Images is to use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these
containers. Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral,
writable layer that only exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the git user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

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

This image is an exception: the runtime variants include `bash`, because the entry point and `sidekiq-cluster` wrapper
under `/scripts` are shell scripts. Other debugging tools are still absent, so use Docker Debug as described above.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
