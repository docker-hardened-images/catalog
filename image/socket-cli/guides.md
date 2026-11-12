## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this socket-cli image

This Docker Hardened socket-cli image includes:

- `socket` -- the main CLI (scan, package score, patch, login, and more)
- `socket-npm` / `socket-npx` -- wrap `npm`/`npx` with Socket security scoring (functional in the `dev` variant, which
  ships npm)

All launchers are on `PATH` at `/usr/local/bin`, so `docker run --entrypoint socket` and Kubernetes
`command: ["socket"]` work as they do after an `npm i -g socket`. The `socket-pnpm` and `socket-yarn` launchers are
present for migration parity only -- no variant ships pnpm or yarn, so they require user-supplied tooling. The runtime
variant ships only the CLI and the Node.js runtime it needs; `npm` and `git` are present only in the `dev` variant.

## Run the container

Running the image with no arguments prints the real usage banner:

```console
$ docker run --rm dhi.io/socket-cli:<tag>
   _____         _       _        /---------------
  |   __|___ ___| |_ ___| |_      | CLI: v1.1.160
  |__   | . |  _| '_| -_|  _|     | token: (not set), org: (not set)
  |_____|___|___|_,_|___|_|.dev   | Command: `socket`, cwd: /work

  CLI for Socket.dev

  Usage
    $ socket <command>
    $ socket scan create --json
    $ socket package score npm lodash --markdown

  Note: All commands have their own --help
```

Check the version:

```console
$ docker run --rm dhi.io/socket-cli:<tag> --version
1.1.160
```

### Authenticate with a Socket API token

Most commands (scanning, package scoring, patch application) require a Socket API token. Create one from your
[Socket.dev](https://socket.dev) organization settings and pass it via `SOCKET_CLI_API_TOKEN`:

```bash
docker run --rm \
  -e SOCKET_CLI_API_TOKEN="$SOCKET_CLI_API_TOKEN" \
  -v "$PWD:/work" \
  dhi.io/socket-cli:<tag> scan create --json .
```

| Variable                  | Description                                                      | Default                      | Required          |
| :------------------------ | :--------------------------------------------------------------- | :--------------------------- | :---------------- |
| `SOCKET_CLI_API_TOKEN`    | Socket API token used to authenticate requests                   | (none)                       | For most commands |
| `SOCKET_CLI_ORG_SLUG`     | Default organization slug (overridable per-command with `--org`) | (none)                       | No                |
| `SOCKET_CLI_API_BASE_URL` | Override the Socket API base URL                                 | `https://api.socket.dev/v0/` | No                |

Without a token, commands that need one fail with a clear error identifying the missing requirement, for example:

```console
$ docker run --rm dhi.io/socket-cli:<tag> package score npm/left-pad
✖  Input error:  Please review the input requirements and try again

  ✔ First parameter must be an ecosystem or the whole purl
  ✔ Expecting at least one package
  ✖ This command requires a Socket API token for access (try `socket login`)
```

### Scan a project

Mount your project and run a scan (requires a token from an organization with API access):

```bash
docker run --rm \
  -e SOCKET_CLI_API_TOKEN="$SOCKET_CLI_API_TOKEN" \
  -v "$PWD:/work" \
  dhi.io/socket-cli:<tag> scan create --no-interactive --json .
```

### Wrap npm/npx (dev variant)

The runtime image intentionally omits `npm`/`git` -- the `socket npm`/`socket npx` wrappers, and `socket fix` (which
commits fix branches via git), need the `dev` variant:

```bash
docker run --rm \
  -e SOCKET_CLI_API_TOKEN="$SOCKET_CLI_API_TOKEN" \
  -v "$PWD:/work" \
  --entrypoint socket \
  dhi.io/socket-cli:<tag>-dev npm install
```

### Reachability analysis and SBOM generation

`socket scan create --reach`, `socket fix`, and `socket cdxgen` lazily download additional tooling (`@coana-tech/cli`,
`@cyclonedx/cdxgen`, `synp`) via `npx` the first time they run -- they are not bundled in the image, and the runtime
variant does not ship `npm`/`npx` at all. These commands **require the `dev` variant** (which has npm and git) plus
outbound network access to the npm registry. Likewise, `socket manifest` subcommands for other ecosystems (gradle,
scala, kotlin, maven, conda) shell out to those ecosystems' own toolchains, which no variant ships -- bring them
yourself in a derived image or run those subcommands outside the container.

### Known limitation: `socket patch` on Alpine

`socket patch apply` depends on a prebuilt native helper binary (`@socketsecurity/socket-patch`) that Socket publishes
for glibc platforms (including `linux/arm64`) but with no musl builds. The x64 binary is statically linked and has been
observed to execute on Alpine, but musl is not an upstream-supported target for it -- treat `socket patch` on the Alpine
variants as unsupported and use the Debian variants for patch workflows. Everything else in the CLI is pure JavaScript
and works identically everywhere.

## Non-hardened images vs. Docker Hardened Images

Socket does not publish an upstream Docker image for this CLI (`socketdev/cli` on Docker Hub is Socket's separate
Python-based scanner, not this project), so there is no upstream container behavior to match. This image runs as the
`nonroot` user by default (unlike a typical local `npm install -g socket` where the CLI runs as whatever user invokes
it), and the runtime variant has no shell -- use the `dev` variant for interactive or wrapper use cases.

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
