## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/rclone:<tag>`
- Mirrored image: `<your-namespace>/dhi-rclone:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start an rclone image

Rclone syncs files and directories between local disks and cloud storage. The full command reference is in the upstream
documentation at https://rclone.org/docs/. This image is the hardened stand-in for `docker.io/rclone/rclone`.

The entrypoint is `/usr/local/bin/rclone` and there is no default command, so pass an rclone subcommand as the container
arguments. The runtime image runs as numeric user 65532 and the working directory is `/data`. The image sets
`XDG_CONFIG_HOME=/config`, so rclone looks for its config file at `/config/rclone/rclone.conf`. The `/data`, `/config`
and `/config/rclone` directories exist and are owned by uid 65532.

Print the rclone version. The first line of the output is `rclone v<version>`.

```bash
docker run --rm dhi.io/rclone:<tag> version
```

## Common rclone use cases

### Sync a host directory

Create a small source tree on the host and mount its parent at `/data`. Pass your own uid and gid with `--user` so the
files rclone writes on the host stay owned by you.

```bash
mkdir -p ~/data/src
echo "hello rclone" > ~/data/src/hello.txt
docker run --rm -v ~/data:/data --user $(id -u):$(id -g) dhi.io/rclone:<tag> sync src backup
docker run --rm -v ~/data:/data --user $(id -u):$(id -g) dhi.io/rclone:<tag> check src backup
```

Relative paths resolve against `/data`, so the first command copies `~/data/src` to `~/data/backup`. The `check` command
logs `0 differences found` when both trees match.

### Keep remotes in a config directory

Rclone stores remotes in `rclone.conf` and rewrites that file with a rename when it refreshes OAuth tokens. Mount the
whole config directory at `/config/rclone`, not just the file.

```bash
mkdir -p ~/.config/rclone
docker run --rm -v ~/.config/rclone:/config/rclone --user $(id -u):$(id -g) dhi.io/rclone:<tag> config create mylocal local
docker run --rm -v ~/.config/rclone:/config/rclone --user $(id -u):$(id -g) dhi.io/rclone:<tag> listremotes
```

The second command prints `mylocal:`. To keep the config in a named volume instead, leave out `--user`. A new volume
takes the owner of `/config/rclone` in the image, so the default user can write it.

```bash
docker run --rm -v rclone-config:/config/rclone dhi.io/rclone:<tag> config create mylocal local
docker run --rm -v rclone-config:/config/rclone dhi.io/rclone:<tag> listremotes
```

The interactive `rclone config` wizard needs `docker run -it`. The image has no web browser, so set up remotes that use
OAuth with `rclone authorize` on a machine that has one, as described at https://rclone.org/remote_setup/.

### Sync to S3 with a remote from environment variables

Rclone also reads remotes from `RCLONE_CONFIG_<NAME>_<OPTION>` environment variables, so no config file is needed. This
example starts rclone's own S3 server as a local endpoint and then syncs `~/data/src` from the first example to it.

```bash
docker network create rclone-demo
mkdir -p ~/s3data
docker run -d --name rclone-s3 --network rclone-demo -v ~/s3data:/data --user $(id -u):$(id -g) \
  dhi.io/rclone:<tag> serve s3 /data --addr :8080 --auth-key demo,demosecret
docker run --rm --network rclone-demo -v ~/data:/data --user $(id -u):$(id -g) \
  -e RCLONE_CONFIG_DEMO_TYPE=s3 \
  -e RCLONE_CONFIG_DEMO_PROVIDER=Rclone \
  -e RCLONE_CONFIG_DEMO_ENDPOINT=http://rclone-s3:8080 \
  -e RCLONE_CONFIG_DEMO_ACCESS_KEY_ID=demo \
  -e RCLONE_CONFIG_DEMO_SECRET_ACCESS_KEY=demosecret \
  dhi.io/rclone:<tag> sync src demo:backup
```

The synced files land in `~/s3data/backup`. For Amazon S3 or another provider, set that provider, endpoint and keys
instead. The S3 options are listed at https://rclone.org/s3/. Remove the demo server with
`docker rm -f rclone-s3 && docker network rm rclone-demo`.

### Use the remote control API

The `rcd` command serves rclone's remote control API. It listens on localhost by default, so `--rc-addr :5572` makes it
listen on the container interface. Publishing the port on `127.0.0.1` keeps it off other hosts.

```bash
docker run -d --name rclone-rc -p 127.0.0.1:5572:5572 -v ~/data:/data:ro --user $(id -u):$(id -g) \
  dhi.io/rclone:<tag> rcd --rc-addr :5572 --rc-user admin --rc-pass changeme
curl -s -u admin:changeme -H 'Content-Type: application/json' -d '{"fs":"/data/src","remote":""}' \
  http://127.0.0.1:5572/operations/list
```

The response lists `hello.txt`. Remove the container with `docker rm -f rclone-rc`. The API is described at
https://rclone.org/rc/.

### Run with a read-only root filesystem

With `--read-only`, rclone needs writable mounts for `/data`, the config directory and a cache directory. The example
puts the config on a tmpfs owned by your uid and points `XDG_CACHE_HOME` at a tmpfs `/tmp`. Commands that keep a cache,
such as `bisync`, write it there.

```bash
docker run --rm --read-only -v ~/data:/data --user $(id -u):$(id -g) \
  --tmpfs /config/rclone:uid=$(id -u),gid=$(id -g) --tmpfs /tmp -e XDG_CACHE_HOME=/tmp/cache \
  dhi.io/rclone:<tag> bisync src backup --resync
```

## FIPS scope

The FIPS variants install an rclone build that links Go's FIPS 140-3 module and turns on `GODEBUG=fips140=on` by
default. TLS and the other Go standard library crypto that rclone uses for its connections run through that module. FIPS
mode also limits the SSH algorithms the sftp backend can negotiate, so SFTP servers that only offer older algorithms
such as `ssh-rsa` host keys can fail to connect. Rclone is a static Go binary and doesn't load OpenSSL. The OpenSSL FIPS
provider in these variants is there for STIG compliance.

Rclone still computes MD5 and SHA-1 checksums in the FIPS variants, so `rclone hashsum md5` and checksum based `check`
and `sync` keep working. The crypt backend uses scrypt, XSalsa20-Poly1305 and EME, and config file encryption uses
XSalsa20-Poly1305. None of these is part of the validated module.

## Non-hardened images vs. Docker Hardened Images

The upstream image runs as root. This image runs as uid 65532, so files on a bind mount must be writable by the
container user. Pass `--user $(id -u):$(id -g)` as the upstream documentation also suggests, or make the host directory
writable by uid 65532. A uid passed with `--user` has no home directory in the image, so commands that keep a cache,
such as `bisync` and `serve sftp`, also need `-e XDG_CACHE_HOME` set to a writable path such as `/data/.cache`.

The upstream entrypoint is `rclone`, found on `PATH` at `/usr/local/bin/rclone`. This image sets the entrypoint to
`/usr/local/bin/rclone`, which is a symlink to `/usr/bin/rclone`. Both paths and plain `rclone` run the same binary.

FUSE mounts are not supported. In the runtime image `rclone mount` and `rclone mount2` fail because there is no
`fusermount3` or `fusermount`, and `rclone nfsmount` fails because there is no `mount` program. The `serve docker`
volume plugin is not supported either. Use `sync`, `copy` or one of the `serve` commands instead.

`rclone selfupdate` is removed. Pull a newer image tag to update rclone.

The runtime image has no shell and no helper programs, apart from the `openssl` command in the FIPS variants. Options
that run an external command, such as `--password-command`, `--metadata-mapper` or the sftp `ssh` option, need an image
built from the `dev` variant that adds the program.

The Debian variants read MIME types from Debian's `media-types` list, so some extensions get a different upload
Content-Type than in the upstream Alpine based image. For example `.xml` becomes `application/xml` instead of
`text/xml`, and `.yaml` becomes `application/yaml` instead of `application/octet-stream`. The Alpine variants use
`mailcap` like upstream and match it.

The upstream image is also published for `linux/386`, `linux/arm/v6` and `linux/arm/v7`. This image is published for
`linux/amd64` and `linux/arm64`.

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

  **rclone is an exception:** rclone's own MD5 and SHA-1 checksums still work in FIPS variants, as described in FIPS
  scope above.

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
