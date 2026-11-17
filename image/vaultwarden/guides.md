## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/vaultwarden:1`
- Mirrored image: `<your-namespace>/dhi-vaultwarden:1`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The unqualified `1` tag is the Debian image. That line is also tagged `1-debian` and `1-debian13`, and with the minor
and patch version of the Debian package (for example `1.37` and `1.37-debian13`). The Alpine 3.24 image does not publish
the unqualified `1` tag. It is tagged `1-alpine`, `1-alpine3.24`, and with its own minor and patch version. Development
tags add `-dev`, for example `1-dev` and `1-alpine3.24-dev`.

Vaultwarden is an unofficial Bitwarden-compatible password server written in Rust, with the web vault included.
Configuration beyond this quick start is in the upstream project at
[github.com/dani-garcia/vaultwarden](https://github.com/dani-garcia/vaultwarden). This image replaces
`vaultwarden/server`.

Bitwarden is a trademark of Bitwarden Inc. Vaultwarden is unofficial and is not affiliated with, sponsored by, or
endorsed by Bitwarden Inc.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.

## Start a Vaultwarden image

The image has an empty entrypoint and its command is `/start.sh`. Starting a container with no extra arguments runs that
script. Arguments placed after the image name replace `/start.sh`. They are not passed to the server. The working
directory is `/`. `/start.sh` is the startup script, `/vaultwarden` is the server binary, and `/web-vault` is the web
vault. The server looks for the vault in the relative directory `web-vault/`.

The server listens on port 80 inside the container. The `vaultwarden` binary has the file capability
`cap_net_bind_service=eip`, so uid 65532 can bind that port. Publish a host port onto container port 80, for example
`-p 8080:80`. Do not move the process to another port unless you also set `ROCKET_PORT` to that same port.

`/data` must exist and be writable by uid 65532, the user the runtime image runs as. This image does not declare a
volume. Unlike `vaultwarden/server`, it still starts when `/data` is not a mount, and then the database lives only in
the container and is lost when the container is removed. Bind-mount a host directory on `/data`, and give that directory
to uid 65532. If the directory is not writable by that user, the server exits because it cannot create its key and
database.

This image has no Docker healthcheck and no `/healthcheck.sh`. Probe `GET /alive`, which returns HTTP 200 with
`Content-Type: application/json`. `GET /api/version` returns a JSON string of the server version. `GET /` returns HTTP
200 `text/html`, and the page references `vaultwarden.css`.

### Run the server

```bash
$ mkdir -p vaultwarden-data
$ sudo chown 65532:65532 vaultwarden-data
$ docker run -d --name vaultwarden \
  -p 8080:80 \
  -v "$(pwd)/vaultwarden-data:/data" \
  dhi.io/vaultwarden:1
```

The `curl` commands retry while the process is still opening port 80.

```bash
$ curl -fsS --retry 10 --retry-delay 1 --retry-all-errors -D - -o /dev/null http://127.0.0.1:8080/alive
$ curl -fsS --retry 10 --retry-delay 1 --retry-all-errors http://127.0.0.1:8080/api/version
$ curl -fsS --retry 10 --retry-delay 1 --retry-all-errors http://127.0.0.1:8080/ | grep -o vaultwarden.css
```

Open http://127.0.0.1:8080/ for the web vault.

### Print the version

```bash
$ docker run --rm --entrypoint /vaultwarden dhi.io/vaultwarden:1 --version
```

The command prints a Vaultwarden line with the server version and a Web-Vault line.

### Environment variables

| Variable         | Description                           | Default   | Required |
| ---------------- | ------------------------------------- | --------- | -------- |
| `ROCKET_ADDRESS` | Address the HTTP server binds         | `0.0.0.0` | No       |
| `ROCKET_PORT`    | Port the HTTP server listens on       | `80`      | No       |
| `ROCKET_PROFILE` | Rocket profile the server starts with | `release` | No       |

These variables are already set in the image. Change `ROCKET_PORT` only when you also change the port the process binds.

### Development variant

A tag that ends in `-dev` runs as root and includes bash. The runtime image does not include bash.

```bash
$ docker run --rm --entrypoint bash dhi.io/vaultwarden:1-dev -c 'id -u'
```

The command prints `0`.

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
