## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Refer to the [upstream Varnish Cache documentation](https://varnish-cache.org/docs/) for complete VCL syntax and
configuration options.

> **Coming from Docker Hub `library/varnish`?** This Hardened Image runs **`varnishd` directly** — there is **no**
> `docker-varnish-entrypoint` wrapper — and **runtime variants have no interactive shell**, so copy-pasted official
> examples often need different `command`, ports, and `docker run` / `docker exec` patterns. Before you migrate, read
> **[Replacing Docker Hub `varnish` (official image)](#replacing-docker-hub-varnish-official-image)** for the full
> checklist (entrypoint, `VARNISH_*` env vars, internal **8080** vs **80**, one-shot CLI containers, and optional
> `VSM_NOPID`).

### What's included in this Varnish image

This Docker Hardened Varnish image includes:

- `varnishd` — HTTP accelerator daemon (container entry point)
- `varnishadm` — CLI for the `varnishd` management interface
- `varnishlog` — Live viewer for shared-memory (SHMLOG) request logs
- `varnishstat` — Runtime counters and statistics
- `varnishhist` — Terminal histogram of request latencies from SHMLOG
- `varnishncsa` — NCSA-style access logs from SHMLOG
- `varnishtop` — Top-like view of the most frequent SHMLOG tags
- `varnishtest` — Varnish Test Case (VTC) harness

All of the above are installed under `/usr/local/bin/`.

## Start a varnish image

### Basic usage

Replace `<tag>` with the image variant you want (for example `8.0` or `8.0.0-debian13`).

```bash
docker run -p 8080:8080 -p 8443:8443 dhi.io/varnish:<tag>
```

The default configuration listens on **8080** (HTTP) and **8443** (PROXY), uses `/etc/varnish/default.vcl`, enables
HTTP/2, and uses `malloc,100M` storage.

Mount your own VCL:

```bash
docker run -p 8080:8080 -p 8443:8443 \
  -v /path/to/default.vcl:/etc/varnish/default.vcl:ro \
  dhi.io/varnish:<tag>
```

### With Docker Compose (recommended for complex setups)

```yaml
services:
  varnish:
    image: dhi.io/varnish:<tag>
    ports:
      - "8080:8080"
      - "8443:8443"
    volumes:
      - ./default.vcl:/etc/varnish/default.vcl:ro
    tmpfs:
      - /var/lib/varnish:exec
```

A `tmpfs` on `/var/lib/varnish` is recommended for low-latency SHM log workloads.

## Common Varnish Cache use cases

### HTTP reverse proxy cache

Create a `default.vcl` pointing at an upstream origin:

```vcl
vcl 4.1;

backend default {
    .host = "origin.example.com";
    .port = "80";
}

sub vcl_recv {
    if (req.method == "PURGE") {
        return (purge);
    }
}
```

```bash
docker run -p 8080:8080 -p 8443:8443 \
  -v $(pwd)/default.vcl:/etc/varnish/default.vcl:ro \
  dhi.io/varnish:<tag>
```

### Adjust cache storage size

By default the image starts `varnishd` with `-s malloc,100M`. To change the cache size, override the container command
with a full `varnishd` argument list:

```bash
docker run -p 8080:8080 -p 8443:8443 dhi.io/varnish:<tag> \
  -F -f /etc/varnish/default.vcl \
  -a http=:8080,HTTP -a proxy=:8443,PROXY \
  -p feature=+http2 \
  -s malloc,1G
```

### Observability tools (`varnishlog`, `varnishstat`, …)

Prefer `docker exec` against a running cache:

```bash
docker exec -it <container> /usr/local/bin/varnishlog
docker exec -it <container> /usr/local/bin/varnishstat
```

For a one-off `docker run` that runs a tool binary (similar to the Docker Official Image entrypoint), set
`--entrypoint`:

```bash
docker run --rm --entrypoint /usr/local/bin/varnishlog dhi.io/varnish:<tag>
```

### Varnish admin CLI (`varnishadm`)

`varnishadm` requires `-T` and `-S` on `varnishd`. The default command does not enable the management interface; start
the cache with management enabled:

```bash
openssl rand -base64 32 > varnish-secret
chmod 644 varnish-secret

docker run -d --name varnish -p 8080:8080 -p 8443:8443 \
  -v $(pwd)/varnish-secret:/etc/varnish/secret:ro \
  dhi.io/varnish:<tag> \
  -F -f /etc/varnish/default.vcl \
  -a http=:8080,HTTP -a proxy=:8443,PROXY \
  -p feature=+http2 \
  -s malloc,100M \
  -T 127.0.0.1:6082 \
  -S /etc/varnish/secret
```

```bash
docker exec -it varnish /usr/local/bin/varnishadm \
  -T 127.0.0.1:6082 \
  -S /etc/varnish/secret \
  ping
```

Binding `-T` to `127.0.0.1` keeps the management interface off the container network; only `docker exec` (or the same
network namespace) can reach it.

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature         | Non-hardened Varnish                | Docker Hardened Varnish                                          |
| --------------- | ----------------------------------- | ---------------------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches                     |
| Shell access    | Full shell (bash/sh) available      | No interactive shell in runtime variants                         |
| Package manager | apt/apk available                   | No package manager in runtime variants                           |
| User            | Often runs as root or `varnish`     | Runs as the nonroot user (UID **65532**)                         |
| Default port    | Binds to port **80** (HTTP) + 8443  | Binds to port **8080** (HTTP) + **8443** — unprivileged          |
| Attack surface  | Larger due to additional utilities  | Minimal runtime; `varnishd` JIT requires gcc/binutils at runtime |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting              |

<a id="replacing-docker-hub-varnish-official-image"></a>

### Replacing Docker Hub `varnish` (official image)

The hardened image matches the **typical** official workload (`varnishd` in the foreground, default VCL path, HTTP/2,
malloc storage, HTTP + PROXY listeners) but **not** the official **container API**:

| Topic                     | Official image (`library/varnish`)                                            | This image (`dhi.io/varnish`)                   | What to do                                                                                                |
| ------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **Entry point**           | `/usr/local/bin/docker-varnish-entrypoint` (shell wrapper)                    | `/usr/local/bin/varnishd`                       | Use **`varnishd` flags** in `command` / `CMD` / `args`, not the wrapper path.                             |
| **Env-based config**      | `VARNISH_VCL_FILE`, `VARNISH_HTTP_PORT`, `VARNISH_PROXY_PORT`, `VARNISH_SIZE` | **Not read**                                    | Override **command** with explicit `varnishd` flags (or template env into command in Compose/Kubernetes). |
| **HTTP port (container)** | **80**                                                                        | **8080**                                        | Publish `8080`, or `-p 80:8080` for host port 80.                                                         |
| **PROXY port**            | **8443**                                                                      | **8443**                                        | Same as official if you use PROXY.                                                                        |
| **User / workdir**        | Often `varnish`, **`WORKDIR` `/etc/varnish`**                                 | **`nonroot`**, **`WORKDIR` `/var/lib/varnish`** | Fix mounts/permissions for UID **65532**. Binaries: **`/usr/local/bin/`**, not `/usr/sbin/`.              |
| **`docker run … tool`**   | Wrapper `exec`s `varnishlog`, etc.                                            | **`varnishd` is always entrypoint**             | Use **`docker exec`** or `docker run --entrypoint /usr/local/bin/<tool>`.                                 |

Equivalent to the official default prefix (already the image default `CMD`; shown for migration from Compose that called
the wrapper):

```bash
docker run -p 8080:8080 -p 8443:8443 dhi.io/varnish:<tag> \
  -F -f /etc/varnish/default.vcl \
  -a http=:8080,HTTP -a proxy=:8443,PROXY \
  -p feature=+http2 \
  -s malloc,100M
```

The official image sets **`VSM_NOPID=1`**; this image does not. Pass **`--env VSM_NOPID=1`** if your runtime depends on
it.

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell for interactive use; runtime images also typically don't
include debugging tools. Common debugging methods for applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
docker debug dhi.io/varnish:<tag>
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-varnish \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/varnish:<tag> /dbg/bin/sh
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

### Varnish-specific migration notes

- **Docker Official Image:** Read **Replacing Docker Hub `varnish` (official image)** for entrypoint, env, and port
  differences before changing image references.
- **VCL file permissions:** UID **65532** must be able to read mounted `default.vcl` (for example `chmod 644` on the
  host file).
- **`/var/lib/varnish`:** Use a `tmpfs` or writable volume; example: `docker run --tmpfs /var/lib/varnish:exec …`.
- **Backend TLS in VCL:** This image builds `varnishd` **without** `--with-ssl`. VCL backend `.tls` usage will not load.
  Terminate TLS in front of Varnish or use plain HTTP to the next hop.

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
