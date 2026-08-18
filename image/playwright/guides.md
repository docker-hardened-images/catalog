## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this playwright image

The runtime variant includes:

- `playwright` — the Playwright CLI and test driver
- `node` — the Node.js runtime used to run the driver
- `bash` and `coreutils` — required by Playwright's bundled WebKit launch scripts
- Version-pinned **Firefox** and **WebKit** browser bundles under `/usr/lib/ms-playwright` (also reachable at
  `/ms-playwright` for upstream path parity), along with their runtime libraries and fonts. The Chromium-compatible
  target at that same path comes from Debian's own `chromium` package instead of a Playwright-pinned bundle, so its
  version tracks Debian's security-patch cadence rather than the `playwright` npm package's pinned revision.

The `-dev` variant additionally includes `npm`, `git`, `xvfb`, `openssh-client`, and `apt` for installing project
dependencies and running browser test suites in CI.

The image ships the `playwright` npm package (the CLI and driver) but does not include `@playwright/test` globally.
Install `@playwright/test` in your own project with the `-dev` variant or in a separate build stage, and pin it to the
same version as the image tag so the version of `@playwright/test` matches the bundled browsers.

### Run the playwright container

```bash
$ docker run --rm dhi.io/playwright:1-debian13 playwright --version
```

The image has no entry point. Its default command is `/bin/bash`, matching the upstream image; pass a command explicitly
for non-interactive use. For example, to see all available `playwright` commands:

```bash
$ docker run --rm dhi.io/playwright:1-debian13 playwright --help
```

## Common playwright use cases

### Run a test suite in CI

Mount your project, install its dependencies, and run your Playwright test suite. The mounted project directory must be
writable by the container user (uid `65532`), so either adjust ownership on the host or run with
`--user "$(id -u):$(id -g)"`. When you override `--user`, also set `HOME` to a writable directory (such as the mounted
project), because npm and the browsers write caches and profiles under `$HOME` and the default `/home/nonroot` is owned
by uid `65532`. Passing `--ipc=host` is recommended so Chromium has enough shared memory and doesn't crash under load:

```bash
$ docker run --rm --ipc=host \
  -v "$(pwd)":/work -w /work \
  --user "$(id -u):$(id -g)" -e HOME=/work \
  dhi.io/playwright:1-debian13-dev \
  bash -lc "npm ci && npx playwright test"
```

### Take a screenshot or generate a PDF

The bundled CLI can capture a screenshot or render a PDF of a page without any project setup. Running with
`--user "$(id -u):$(id -g)"` keeps the mounted output directory writable and the captured file owned by you (the
container user must have write permission on the mounted directory, and `HOME` must point somewhere writable):

```bash
$ mkdir -p out
$ docker run --rm -v "$(pwd)/out":/out -w /out \
  --user "$(id -u):$(id -g)" -e HOME=/tmp \
  dhi.io/playwright:1-debian13 \
  playwright screenshot https://example.com example.png
```

### Use as a browser-test stage in Docker Compose

Run your Playwright test suite against another service in the same Compose stack:

```yaml
services:
  app:
    image: nginx:alpine
    volumes:
      - ./app-html:/usr/share/nginx/html:ro

  playwright:
    image: dhi.io/playwright:1-debian13-dev
    depends_on:
      - app
    working_dir: /work
    volumes:
      - ./tests:/work
    environment:
      - BASE_URL=http://app
    ipc: host
    command: bash -lc "npm ci && npx playwright test"
```

The `app` service serves the site under test (replace `nginx:alpine` and `./app-html` with your own application image
and static assets), and the `playwright` service runs the test suite in `./tests` against it over the internal
`BASE_URL`.

### Advanced topics

- To run browsers in headed mode inside a container, use the `-dev` variant and start them under its bundled virtual
  display, for example `docker run --rm --init dhi.io/playwright:1-debian13-dev xvfb-run npx playwright test --headed`.
  Run the container with `--init` (or wrap `xvfb-run` in a shell command): as PID 1, `xvfb-run` never receives the X
  server's readiness signal and hangs. See the upstream [Playwright in Docker](https://playwright.dev/docs/docker)
  documentation for details.
- To sandbox Chromium while running as a non-root user, apply a custom seccomp profile such as upstream's
  [`seccomp_profile.json`](https://github.com/microsoft/playwright/blob/main/utils/docker/seccomp_profile.json).
- To share browsers across multiple short-lived clients, run Playwright as a
  [server](https://playwright.dev/docs/docker#run-the-server) and connect over CDP instead of launching a new browser
  per container.

## Non-hardened images vs Docker Hardened Images

| Item               | Upstream `mcr.microsoft.com/playwright`                              | Docker Hardened `playwright`                                                                       |
| ------------------ | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Base OS            | Ubuntu 24.04                                                         | Debian 13                                                                                          |
| User               | Runs as root by default (`pwuser` account also available)            | Runs as the nonroot user (uid `65532`); there is no `pwuser` account                               |
| Browser location   | `/ms-playwright`                                                     | `/usr/lib/ms-playwright`, with `/ms-playwright` kept as a symlink for parity                       |
| Package manager    | `apt` and `npm` available in all tags                                | `apt` and `npm` only in the `-dev` variant                                                         |
| Additional tooling | Includes `bash`, `git`, `yarn`, `openssh-client`, `curl`, and `wget` | Runtime retains `bash` and coreutils for WebKit; `git`, `xvfb`, and `openssh-client` are in `-dev` |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a package manager. This image is an exception to the usual "no shell" rule: it keeps `bash` and
    coreutils because Playwright's bundled WebKit browser launches through upstream bash scripts.
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants. The Node.js runtime that executes the
  Playwright driver uses the validated OpenSSL provider in these variants; the bundled browsers keep their own vendored
  crypto, so browser TLS is not in the FIPS boundary.

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
| Shell              | Playwright's bundled WebKit browser launches through upstream bash scripts, so this runtime retains `bash` and coreutils. Use the `-dev` variant for general shell workflows and development tooling.                                                                                                                        |

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

Most hardened images intended for runtime don't contain a shell or debugging tools. This runtime retains `bash` and
coreutils only because Playwright's bundled WebKit launcher requires them. The recommended method for debugging
applications built with Docker Hardened Images is still to use
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

Playwright's bundled WebKit browser launches through upstream bash scripts, so the runtime image retains `bash` and
coreutils. General-purpose development tools such as npm, git, and xvfb remain limited to the `-dev` variant. Docker
Debug is still preferred for debugging containers without modifying them.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
