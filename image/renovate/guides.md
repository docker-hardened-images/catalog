## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/renovate:44-debian13` or `dhi.io/renovate:44-alpine3.24`
- Mirrored image: `<your-namespace>/dhi-renovate:44-debian13` or `<your-namespace>/dhi-renovate:44-alpine3.24`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Debian publishes the unqualified tag `44` and the line tag `44-debian13`. Alpine publishes the line tags `44-alpine` and
`44-alpine3.24`. The commands below use the line tag for each distribution.

Renovate is a command-line tool. A run scans a project directory and exits. It does not listen on a port. Project
documentation is at https://github.com/renovatebot/renovate and https://docs.renovatebot.com/.

### What's included in this Renovate image

This Docker Hardened Renovate image includes:

- `renovate` — Scans a repository and looks up newer versions of pinned dependencies.
- `renovate-config-validator` — Checks a Renovate config file and exits non-zero on an unknown option.

The entrypoint is `/usr/local/sbin/renovate-entrypoint.sh`. When the first argument starts with `-`, or is not an
executable on `PATH`, the entrypoint runs `renovate` with those arguments. Both binaries above are on `PATH`.

## Start a Renovate image

### Check the version

This example uses the Debian image:

```bash
$ docker run --rm dhi.io/renovate:44-debian13 --version
```

The command prints the image's Renovate version.

### Scan a local project

The [local platform](https://docs.renovatebot.com/modules/platform/local/) scans the working directory inside the
container, `/usr/src/app`, and does not open a pull request. Mount the project on that path. The directory and its files
must be readable by uid 65532.

Create `package.json`:

```json
{
  "name": "demo",
  "dependencies": {
    "lodash": "4.17.20"
  }
}
```

Create `renovate.json`:

```json
{
  "extends": []
}
```

From the directory that contains those files, run the Debian image. `--platform=local` selects the local platform.
`--onboarding=false` skips the onboarding branch because `renovate.json` is already present. `--dry-run=extract` stops
after reading dependency files.

```bash
$ docker run --rm -v "$PWD:/usr/src/app" dhi.io/renovate:44-debian13 --platform=local --onboarding=false --dry-run=extract
```

Renovate reports the pinned `lodash` dependency from `package.json` and exits 0. The local platform's default is a
lookup dry run, which queries package registries over the network. The command above passes `--dry-run=extract` so it
stops before that lookup. See the local platform documentation for lookup mode.

## Common Renovate use cases

### Validate a configuration file

`renovate-config-validator` checks a config file. This example uses the Alpine image. Save the following as `config.js`.
The file must be readable by uid 65532.

```js
module.exports = {
  platform: 'local',
};
```

```bash
$ docker run --rm -v "$PWD/config.js:/usr/src/app/config.js:ro" dhi.io/renovate:44-alpine3.24 renovate-config-validator /usr/src/app/config.js
```

The validator prints `Config validated successfully`.

## Non-hardened images vs. Docker Hardened Images

This image replaces `docker.io/renovate/renovate` for the Renovate CLI. The entrypoint remains
`/usr/local/sbin/renovate-entrypoint.sh`, the default command remains `renovate`, and the working directory remains
`/usr/src/app`. The differences below change a migrated run.

**User id.** Upstream runs as uid 12021. This runtime image runs as uid 65532, group 65532. A volume created for uid
12021 is not writable by uid 65532. Grant uid 65532 read access to every mounted path, and write access where Renovate
must update files. Dev images (`44-debian13-dev` and `44-alpine3.24-dev`) and the `fips-dev` variants run as root.

**Binary source.** This image sets `RENOVATE_BINARY_SOURCE=global`. Upstream leaves that variable unset, which selects
`binarySource=install`: containerbase downloads package managers during the run. This image does not download package
managers at runtime. `git`, `bash`, and `node` are already on `PATH`. Bash is present because the entrypoint is a bash
script. The image does not include containerbase, OpenSSH, curl, or GnuPG, and it is not the upstream `-full` image.

**Directories.** These paths exist with mode `0770` and owner `65532:65532`:

- `/tmp/renovate`
- `/runner/cache/renovate/repository`
- `/usr/src/app`
- `/home/nonroot`

Upstream creates the cache paths with mode `0777`. A mount that replaces one of these directories must be writable by
uid 65532.

**Shell environment.** This image sets `LANG=C.UTF-8` and `LC_ALL=C.UTF-8`. Upstream sets `BASH_ENV` and `ENV` to
`/usr/local/etc/env`. This image does not set `BASH_ENV` or `ENV`, so a shell does not source `/usr/local/etc/env`.

**Init.** PID 1 is tini at `/usr/local/sbin/tini`. Upstream uses dumb-init.

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
