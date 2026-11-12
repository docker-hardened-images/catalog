## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/gitlab-toolbox:<tag>`
- Mirrored image: `<your-namespace>/dhi-gitlab-toolbox:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this GitLab Toolbox image

This Docker Hardened GitLab Toolbox image includes:

- The GitLab Community Edition Rails application at `/srv/gitlab`, with its gem bundle installed
- `backup-utility` — creates, restores, and prunes full GitLab backups
- `gitlab-rake`, `gitlab-rails`, `gitlab-backup-cli` — wrappers that run rake tasks, the Rails console, and the backup
  CLI against the installed application
- `gitaly-backup` — streams repository backups to and from Gitaly, built for the same GitLab version as this image
- `object-storage-backup` and `object-storage-restore` — move object storage buckets in and out of a backup archive
- `aws` (AWS CLI), `s3cmd`, `gsutil`, and `azcopy` for the S3, Google Cloud Storage, and Azure backup backends
- `pg_dump` and `psql` from the PostgreSQL 17 client, `redis-cli`, `git`, `jq`, `tar`, `gzip`, and `openssl`

## Start a GitLab Toolbox instance

GitLab Toolbox is a maintenance client, not a service. It exposes no ports and does nothing on its own: it needs a
mounted GitLab configuration and network access to the PostgreSQL, Redis, and Gitaly services of an existing GitLab
deployment. In a Kubernetes deployment the GitLab Helm chart runs this image as a `Deployment` for interactive use and
as a `CronJob` for scheduled backups.

### Check the version

```bash
$ docker run --rm dhi.io/gitlab-toolbox:<tag> cat /srv/gitlab/VERSION
```

The toolbox version must match the version of the GitLab deployment it operates on.

### Run a maintenance task

The entry point renders any `.erb` templates found in the configuration directory, then runs the command you pass from
`/srv/gitlab`:

Mount your config into a separate template directory rather than over `/srv/gitlab/config`: that path holds the Rails
tree (`application.rb`, `boot.rb`, `routes.rb`), and shadowing it makes `Rakefile`'s `require config/application` fail,
so neither `gitlab-rake` nor `backup-utility` starts.

```bash
$ docker run --rm \
  -v ./gitlab-config:/var/opt/gitlab/config/templates \
  -e CONFIG_TEMPLATE_DIRECTORY=/var/opt/gitlab/config/templates \
  -e CONFIG_DIRECTORY=/srv/gitlab/config \
  dhi.io/gitlab-toolbox:<tag> \
  gitlab-rake gitlab:env:info
```

### Create a backup

`backup-utility` writes a full backup archive and uploads it to object storage. It reads its configuration from the
mounted GitLab config and from environment variables:

```bash
$ docker run --rm \
  -v ./gitlab-config:/var/opt/gitlab/config/templates \
  -v ./s3cmd.config:/etc/gitlab/objectstorage/s3cmd.config:ro \
  -e CONFIG_TEMPLATE_DIRECTORY=/var/opt/gitlab/config/templates \
  -e CONFIG_DIRECTORY=/srv/gitlab/config \
  -e BACKUP_BUCKET_NAME=gitlab-backups \
  dhi.io/gitlab-toolbox:<tag> \
  backup-utility --backend s3 --s3config /etc/gitlab/objectstorage/s3cmd.config
```

Run `backup-utility --help` for the full option list, including `--restore`, `--skip`, `--maximum-backups`, and
`--repositories-server-side`.

### Environment variables

| Variable                    | Description                                                        | Default                             | Required |
| --------------------------- | ------------------------------------------------------------------ | ----------------------------------- | -------- |
| `CONFIG_TEMPLATE_DIRECTORY` | Directory the entry point reads `.erb` config templates from       | `/srv/gitlab/config`                | No       |
| `CONFIG_DIRECTORY`          | Directory the rendered config is written to                        | same as `CONFIG_TEMPLATE_DIRECTORY` | No       |
| `BACKUP_BUCKET_NAME`        | Object storage bucket that backup archives are written to          | `gitlab-backups`                    | No       |
| `BACKUP_BACKEND`            | Backup object storage backend: `s3`, `gcs`, or `azure`             | `s3`                                | No       |
| `S3_TOOL`                   | S3 client that `backup-utility` runs: `s3cmd` or `awscli`          | `s3cmd`                             | No       |
| `BACKUP_TIMESTAMP`          | Timestamp of the archive to restore, used with `--restore`         | unset                               | No       |
| `USE_GITLAB_LOGGER`         | Set to `0` in this image; see the differences section below        | `0`                                 | No       |
| `USE_TINI`                  | Set to `0` to start the command directly instead of through `tini` | `1`                                 | No       |

## Non-hardened images vs. Docker Hardened Images

This image differs from `registry.gitlab.com/gitlab-org/build/cng/gitlab-toolbox-ce` in ways that affect what it can do.

**Edition.** Only GitLab Community Edition is built. There is no Enterprise Edition variant, and Enterprise-only
maintenance tasks are therefore unavailable.

**Container logs are raw lines, not structured JSON.** Upstream runs `gitlab-logger` by default, which re-emits
`/var/log/gitlab` to stdout as JSON. Here `USE_GITLAB_LOGGER` is set to `0`, and the container prints the log lines as
they are written.

This is the one difference likely to affect you operationally: if your log pipeline parses container stdout as JSON, it
will not do so here, and output from multiple log files is interleaved without a per-file marker. The log files
themselves are unchanged — `/var/log/gitlab/*.log` still contains GitLab's own structured output, so shipping logs from
the files rather than from stdout gives you the same data as upstream.

**No `/srv/gitlab/doc`.** Upstream ships GitLab's documentation tree inside the image; it is removed here. Nothing reads
it at runtime. Read the docs at <https://docs.gitlab.com> instead. GitLab's `LICENSE` and every gem licence file are
untouched.

**No `screen`.** The upstream image installs the `screen` terminal multiplexer, but nothing in the image invokes it — it
is there for interactive use when an operator execs into the pod. It is omitted here because this image ships only what
the runtime needs. If you rely on it, install it in the `dev` variant (`apt-get install screen`), or keep long tasks
alive with a Kubernetes Job or `nohup` instead of a detached session.

#### Why bash is present

Unlike most Docker Hardened Images, the GitLab Toolbox image **does include a shell** (bash and `/bin/sh`) in the
runtime variant. This is a functional requirement: every entry point into this image is a shell script.
`backup-utility`, `process-wrapper.sh`, the `gitlab-rake` / `gitlab-rails` / `gitlab-backup-cli` wrappers, and the
`entrypoint.sh` and `set-config` scripts are all bash, and `backup-utility` also calls `awk`, `tar`, `gzip`, `curl` and
`jq`. Removing the shell would leave the image unable to run anything.

You therefore do **not** need the `dev` variant just to run maintenance commands — `docker run … gitlab-rake …` works
against the runtime tag. The `dev` variant is for `apt` and root access, not for shell availability.

The image still drops the rest of the usual attack surface: there is no package manager (`apt`, `apt-get`, `dpkg`), no
editors, no `ps` and no pager in the runtime variant, though upstream inherits the last two from `gitlab-base`. The
`dev` variant ships them. For interactive debugging, use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/):

```bash
$ docker debug <container>
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  This image is an exception to the shell bullet: its runtime variant ships bash because the GitLab wrapper scripts are
  shell scripts. It still ships no package manager. See [Why bash is present](#why-bash-is-present).

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

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. This image is an exception — its runtime variant ships bash because the GitLab wrapper scripts require it, so you do not need a `dev` tag to run maintenance commands. See [Why bash is present](#why-bash-is-present).                             |

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

Hardened runtime images usually contain neither a shell nor debugging tools. This image ships bash plus the utilities
its wrapper scripts need (`awk`, `curl`, `jq`, `tar`, `gzip`, `less`, `procps`), but nothing beyond that. For anything
further, the recommended method for debugging applications built with Docker Hardened Images is to use
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

By default, image variants intended for runtime don't contain a shell, and you would use `dev` images in build stages to
run shell commands before copying artifacts into the runtime stage.

This image does not have that constraint: its runtime variant includes bash, because `backup-utility` and the
`gitlab-rake` / `gitlab-rails` wrappers are shell scripts. Reach for the `dev` variant when you need `apt` or root, not
merely to run a shell. See [Why bash is present](#why-bash-is-present).

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
