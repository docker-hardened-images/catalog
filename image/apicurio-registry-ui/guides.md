## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/apicurio-registry-ui:<tag>`
- Mirrored image: `<your-namespace>/dhi-apicurio-registry-ui:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image is the [Apicurio Registry](https://www.apicur.io/registry/) web console: the React application, the API
design editors, and the API documentation viewer, served by nginx. It replaces `apicurio/apicurio-registry-ui`. It does
not include the Apicurio Registry server; the UI calls the server's REST API from the browser.

Two release lines are published. Tags `3`, `3.3`, and `3.3.4` follow the current 3.3 line. Tags `3.2` and `3.2.6` follow
the previous 3.2 line, which upstream supports until Apicurio Registry 3.4.0 is released. Use the UI line that matches
your Registry server version. Tags without a distro suffix are Debian 13; Alpine 3.24 tags end in `-alpine`, for example
`3-alpine` or `3.2-alpine`.

## Start an apicurio-registry-ui image

The UI listens on port 8080 for HTTP and on port 1337 for HTTPS.

### Basic usage

This example expects an Apicurio Registry server on the host at port 8080:

```bash
docker run -d --name apicurio-registry-ui -p 8888:8080 \
  -e REGISTRY_API_URL=http://localhost:8080/apis/registry/v3 \
  dhi.io/apicurio-registry-ui:<tag>
```

Open http://localhost:8888/. The page title is Apicurio Registry. Client routes such as http://localhost:8888/explore
return the same page, and the API design editors are at http://localhost:8888/editors/. The configuration generated at
startup is served at http://localhost:8888/config.js with `Cache-Control: no-cache`. `GET /config.js` on port 8080 also
works as a readiness or liveness probe.

### With Docker Compose

This example runs the upstream Apicurio Registry server with its default in-memory storage next to the UI. The browser
calls the server directly, so `REGISTRY_API_URL` is the address the browser uses, and the server must allow the UI's
origin for CORS.

```yaml
services:
  registry:
    image: apicurio/apicurio-registry:3.3.4
    ports:
      - "8080:8080"
    environment:
      QUARKUS_HTTP_CORS_ORIGINS: "http://localhost:8888"
  registry-ui:
    image: dhi.io/apicurio-registry-ui:<tag>
    ports:
      - "8888:8080"
    environment:
      REGISTRY_API_URL: "http://localhost:8080/apis/registry/v3"
    depends_on:
      - registry
```

Run `docker compose up -d`, then open http://localhost:8888/.

### Environment variables

The entrypoint writes these variables into `/config.js` on every start. None of them is set in the image.

| Variable                     | Description                                                         | Default when unset                       |
| ---------------------------- | ------------------------------------------------------------------- | ---------------------------------------- |
| `REGISTRY_API_URL`           | Registry core REST API (v3) that the browser calls.                 | `http://localhost:8080/apis/registry/v3` |
| `REGISTRY_CONTEXT_PATH`      | Path prefix the UI is published under. Rewrites the HTML base href. | `/`                                      |
| `REGISTRY_DOCS_URL`          | URL of the API documentation viewer.                                | `<context path>docs`                     |
| `REGISTRY_EDITORS_URL`       | URL of the API design editors.                                      | `<context path>editors`                  |
| `REGISTRY_AUTH_TYPE`         | Set to `oidc` to sign in through an OpenID Connect provider.        | No authentication                        |
| `REGISTRY_AUTH_URL`          | OpenID Connect provider URL, used when `REGISTRY_AUTH_TYPE=oidc`.   |                                          |
| `REGISTRY_AUTH_CLIENT_ID`    | OpenID Connect client ID.                                           |                                          |
| `REGISTRY_AUTH_REDIRECT_URL` | Redirect URL registered for that client.                            |                                          |
| `REGISTRY_FEATURE_READ_ONLY` | Set to `true` to run the UI in read-only mode.                      |                                          |

The other `REGISTRY_AUTH_*`, `REGISTRY_FEATURE_*`, `REGISTRY_DELETE_*_ENABLED`, and `REGISTRY_NAV_PREFIX_PATH` variables
work as they do upstream; `/usr/lib/apicurio-registry-ui/create-config.cjs` in the image lists all of them.
`REGISTRY_AUTH_USE_NONCE` is read on 3.3 tags only. Leave `REGISTRY_CONFIG_OUTPUT_PATH` and `REGISTRY_INDEXHTML_PATH`
unset: nginx serves `/config.js` and `/index.html` only from their default location.

```bash
docker run -d --name apicurio-registry-ui -p 8888:8080 \
  -e REGISTRY_API_URL=https://registry.example.com/apis/registry/v3 \
  -e REGISTRY_AUTH_TYPE=oidc \
  -e REGISTRY_AUTH_URL=https://keycloak.example.com/realms/registry \
  -e REGISTRY_AUTH_CLIENT_ID=apicurio-registry-ui \
  -e REGISTRY_AUTH_REDIRECT_URL=https://registry-ui.example.com/ \
  dhi.io/apicurio-registry-ui:<tag>
```

## Common apicurio-registry-ui use cases

### Serve the UI under a path prefix

nginx in the container always serves the UI at `/`. When a reverse proxy publishes it under a prefix, set
`REGISTRY_CONTEXT_PATH` to that prefix, with a trailing slash, and have the proxy strip the prefix. The documentation
and editors URLs follow the context path unless you set them.

```bash
docker run -d --name apicurio-registry-ui -p 8888:8080 \
  -e REGISTRY_CONTEXT_PATH=/ui/ \
  -e REGISTRY_API_URL=https://registry.example.com/apis/registry/v3 \
  dhi.io/apicurio-registry-ui:<tag>
```

An nginx reverse proxy for that container:

```nginx
location /ui/ {
    proxy_pass http://apicurio-registry-ui:8080/;
}
```

### Serve HTTPS with your own certificate

On port 1337, nginx uses a self-signed RSA 2048 certificate and key that the entrypoint generates when none are present
at startup. To use your own, mount both the certificate and its key; the key must be readable by UID 65532, or by the
UID you run the container as.

```bash
docker run -d --name apicurio-registry-ui -p 8443:1337 \
  -v "$PWD/server.crt:/etc/pki/nginx/server.crt:ro" \
  -v "$PWD/server.key:/etc/pki/nginx/private/server.key:ro" \
  dhi.io/apicurio-registry-ui:<tag>
```

Open https://localhost:8443/. Port 1337 serves HTTP/2 and the same content as port 8080.

### Add nginx configuration

nginx includes `/opt/app-root/etc/nginx.d/*.conf` in the `http` block and `/opt/app-root/etc/nginx.default.d/*.conf` in
both server blocks, as upstream does. Both directories are empty and read-only, so mount your files into them.

```bash
cat > gzip.conf <<'EOF'
gzip on;
gzip_types application/javascript text/css;
EOF
cat > headers.conf <<'EOF'
add_header X-Frame-Options SAMEORIGIN always;
EOF

docker run -d --name apicurio-registry-ui -p 8888:8080 \
  -v "$PWD/gzip.conf:/opt/app-root/etc/nginx.d/gzip.conf:ro" \
  -v "$PWD/headers.conf:/opt/app-root/etc/nginx.default.d/headers.conf:ro" \
  dhi.io/apicurio-registry-ui:<tag>
```

Arguments you pass to the container replace the `nginx -g 'daemon off;'` command after the configuration is generated.
For example, `docker run --rm dhi.io/apicurio-registry-ui:<tag> nginx -t` checks the nginx configuration and exits.

### Run as an arbitrary user ID

The directories the entrypoint writes to are writable by group 0, so the image runs under any UID whose group is 0, as
on OpenShift with the restricted security context constraint:

```bash
docker run -d --name apicurio-registry-ui -p 8888:8080 --user 12345:0 \
  dhi.io/apicurio-registry-ui:<tag>
```

### Run with a read-only root filesystem

The entrypoint writes to `/var/lib/apicurio-registry-ui` (`config.js` and `index.html`), `/etc/pki/nginx` and
`/etc/pki/nginx/private` (the generated certificate and key), and nginx writes to `/tmp`. Mount a writable volume at
each of them, for example an `emptyDir` in Kubernetes:

```bash
docker run -d --name apicurio-registry-ui -p 8888:8080 --read-only \
  --tmpfs /tmp:mode=1777 \
  --tmpfs /var/lib/apicurio-registry-ui:uid=65532,gid=0,mode=0770 \
  --tmpfs /etc/pki/nginx:uid=65532,gid=0,mode=0770 \
  --tmpfs /etc/pki/nginx/private:uid=65532,gid=0,mode=0770 \
  dhi.io/apicurio-registry-ui:<tag>
```

If you mount your own certificate and key, you don't need the two `/etc/pki/nginx` mounts.

## Non-hardened images vs. Docker Hardened Images

The upstream `apicurio/apicurio-registry-ui` image is built on the Red Hat UBI nginx image. The differences that affect
a migration are:

- **User**: the image runs as UID 65532 (`nginx`) and GID 65532 instead of UID 1001. Update a `runAsUser: 1001` to
  `65532`, or keep an arbitrary UID with group 0 as described above.
- **Entrypoint**: `/usr/local/bin/entrypoint.sh` with the command `nginx -g 'daemon off;'` replaces upstream's
  `container-entrypoint` wrapper and the UBI `run` script. A command of `/usr/local/bin/entrypoint.sh`, which is
  upstream's default command, still starts the UI.
- **Startup features of the UBI base**: `nginx-start/*.sh` hook scripts, `NGINX_LOG_TO_VOLUME`, the other `NGINX_*`
  variables, and the `nss_wrapper` user entry for arbitrary UIDs are not available. Put nginx settings in the extension
  directories instead of hook scripts. nginx always logs to stdout and stderr.
- **Web root**: the UI files are read-only in `/usr/share/apicurio-registry-ui`. `/opt/app-root/src` links to it and is
  still the working directory. `config.js` and `index.html` are generated in `/var/lib/apicurio-registry-ui` on every
  start, so a `config.js` mounted at `/opt/app-root/src/config.js` is not served. Configure the UI with `REGISTRY_*`
  variables, or mount your file read-only at `/var/lib/apicurio-registry-ui/config.js`; the entrypoint then logs that it
  cannot write the file and serves yours.
- **TLS key**: upstream ships one self-signed key inside the image. This image generates a key in each container
  instead, at the same paths, so a certificate and key mounted there are used as before.
- **TLS ciphers**: the `ssl_ciphers PROFILE=SYSTEM` setting, which only exists on Red Hat systems, is removed; nginx and
  OpenSSL defaults apply.
- **Ports**: port 8443 is not exposed. Nothing listened on it upstream either.
- **nginx version**: the image ships nginx 1.30 from the stable line instead of nginx 1.26.
- **Shell**: runtime images keep `/bin/sh` (dash on Debian, BusyBox on Alpine), `node`, and `openssl` because the
  entrypoint needs them. They have no package manager. Use a `dev` tag to debug interactively.

Dev tags, such as `3-dev` or `3.2-alpine-dev`, run as root and include a shell and the system package manager (`apt` on
Debian, `apk` on Alpine). They use the same entrypoint and command, so you can use them in place of a runtime tag while
you debug, or as the build stage of an image that adds files to the UI.

FIPS tags, such as `3-fips` or `3.2-alpine-fips`, use the OpenSSL FIPS provider for nginx TLS on port 1337, for the
`openssl` command that generates the certificate, and for `node`. TLS clients must negotiate FIPS-approved ciphers:
AES-GCM suites work, and ChaCha20-Poly1305 is refused.

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
