## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About stunnel

stunnel is a TLS encryption proxy designed to add SSL/TLS protection to programs that have no native TLS support. It
acts as a wrapper between clients and servers, terminating or initiating TLS connections and forwarding the underlying
plaintext traffic to a local or remote endpoint. A single stunnel process can serve multiple named service sections from
one configuration file, making it suitable for securing SMTP, IMAP, LDAP, database clients, and any other TCP-based
protocol.

This image is built directly from the [official upstream source](https://github.com/mtrojnar/stunnel) and compiled with
`--enable-fips` so the binary supports FIPS mode when paired with a FIPS-capable OpenSSL provider. The image does not
ship a default configuration file. You must supply a `stunnel.conf` by volume mount or by extending the image.

### Run the stunnel container

stunnel requires a configuration file to start. The default CMD passed to the entrypoint is `/etc/stunnel/stunnel.conf`.
Running the container without that file causes stunnel to exit with a configuration error.

To display the stunnel version and compiled-in options:

```bash
docker run --rm --entrypoint /usr/bin/stunnel dhi.io/stunnel:<tag> -version
```

To display help:

```bash
docker run --rm --entrypoint /usr/bin/stunnel dhi.io/stunnel:<tag> -help
```

## Configuration

stunnel has no exposed ports by default. All ports are defined in `stunnel.conf` using `accept` and `connect`
directives. You must publish whatever port the `accept` directive listens on with `-p` or in your Compose file.

### Minimal configuration example

The following `stunnel.conf` wraps a plaintext backend on `127.0.0.1:8080` with TLS, accepting connections on port 8443:

```ini
; Global options
foreground = yes

[https-wrapper]
accept  = 8443
connect = 127.0.0.1:8080
cert    = /etc/stunnel/certs/server.pem
```

`foreground = yes` is required when running inside a container so stunnel does not daemonize. The pid file is disabled
implicitly because the runtime image runs as a nonroot user with no writable home; with `foreground = yes` stunnel does
not need one.

Store your certificate and private key (concatenated) in a single PEM file, for example:

```bash
cat server.crt server.key > server.pem
```

### Run with a volume-mounted configuration

```bash
docker run -d --name stunnel \
  -p 8443:8443 \
  -v /path/to/your/stunnel.conf:/etc/stunnel/stunnel.conf:ro \
  -v /path/to/your/certs:/etc/stunnel/certs:ro \
  dhi.io/stunnel:<tag>
```

### Docker Compose example

```yaml
services:
  stunnel:
    image: dhi.io/stunnel:<tag>
    ports:
      - "8443:8443"
    volumes:
      - ./config/stunnel.conf:/etc/stunnel/stunnel.conf:ro
      - ./certs:/etc/stunnel/certs:ro
    restart: unless-stopped
```

### Client mode: adding TLS to an outbound connection

stunnel can also act as a TLS client, useful when a local application needs to connect to a remote TLS endpoint but does
not support TLS itself. The following example accepts plaintext connections on `127.0.0.1:5432` and forwards them as TLS
to a remote PostgreSQL server:

```ini
foreground = yes

[pg-tls-client]
client  = yes
accept  = 127.0.0.1:5432
connect = db.example.com:5432
```

Point your PostgreSQL client at `localhost:5432` and stunnel handles the TLS handshake transparently.

For the full configuration reference, see the [stunnel manual page](https://www.stunnel.org/static/stunnel.html).

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## FIPS

The `fips` and `fips-dev` variants replace Debian's standard `libssl3` with the DHI OpenSSL FIPS provider package
(`dhi/pkg-openssl:...-debian13-fips`). The stunnel binary in all variants is compiled with `--enable-fips`, so it can
load and use the FIPS provider when the library is present.

To opt into FIPS mode at runtime, add `fips = yes` to the global section of your `stunnel.conf`:

```ini
fips = yes
foreground = yes

[my-service]
accept  = 8443
connect = 127.0.0.1:8080
cert    = /etc/stunnel/certs/server.pem
```

With `fips = yes`, stunnel instructs OpenSSL to activate the FIPS provider. Any cipher or algorithm not permitted under
FIPS 140 will be refused. Use a `fips`-tagged image alongside this setting; the standard runtime image does not include
the FIPS-validated provider library.

These images are STIG-certified through the DHI OpenSSL FIPS include, which provides the validated cryptographic module.

## Migrate from dockurr/stunnel

The `dockurr/stunnel` image is a third-party Docker Hub repackage and is not maintained by the stunnel upstream project.
The DHI stunnel image is built directly from the official [mtrojnar/stunnel](https://github.com/mtrojnar/stunnel) source
repository.

The stunnel configuration file format is identical between the two images. Migration requires only an image reference
change. No configuration edits are needed.

Replace the image reference in your `docker run` command or Compose file:

```yaml
# Before
image: dockurr/stunnel

# After
image: dhi.io/stunnel:<tag>
```

The following table summarises other differences to be aware of:

| Item         | dockurr/stunnel           | dhi.io/stunnel                                                    |
| :----------- | :------------------------ | :---------------------------------------------------------------- |
| Source       | Third-party repackage     | Built from official mtrojnar/stunnel source                       |
| Config path  | /etc/stunnel/stunnel.conf | /etc/stunnel/stunnel.conf (identical)                             |
| Default user | root                      | nonroot (use `-dev` variant for root access)                      |
| Shell        | Present                   | Not present in runtime variant; use `dev` variant or Docker Debug |
| FIPS support | Not available             | Available via `fips` and `fips-dev` variants                      |

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
