## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a go-httpbin instance

The server listens on port 8080. go-httpbin has no authentication, so the example publishes the port on the loopback
interface only:

```bash
$ docker run -d --name go-httpbin -p 127.0.0.1:8080:8080 dhi.io/go-httpbin:<tag>
```

Send a request and go-httpbin echoes it back as JSON:

```console
$ curl -s 'http://127.0.0.1:8080/get?probe=dhi'
{
  "args": {
    "probe": [
      "dhi"
    ]
  },
  ...
  "method": "GET",
  "origin": "172.17.0.1",
  "url": "http://127.0.0.1:8080/get?probe=dhi"
}
```

Configure the server with command-line flags or the matching environment variables; flags take precedence. This example
moves the listener to port 9090 and reports the full build details on `/version`:

```console
$ docker run -d --name go-httpbin -e PORT=9090 -e USE_FULL_VERSION=true -p 127.0.0.1:9090:9090 \
  dhi.io/go-httpbin:<tag>
$ curl -s http://127.0.0.1:9090/version
{
  "service": "go-httpbin",
  "version": "<version>",
  ...
}
```

Replace `<version>` with the go-httpbin version of the tag you run. The full list of flags and environment variables is
in the [go-httpbin README](https://github.com/mccutchen/go-httpbin#configuration).

## Common go-httpbin use cases

### Serve over HTTPS

go-httpbin serves HTTPS when given a certificate and key. The files must be readable by the nonroot user (UID 65532):

```bash
$ openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 365 \
  -subj "/CN=localhost" -keyout server.key -out server.crt
$ chmod 644 server.crt server.key
$ docker run -d --name go-httpbin -p 127.0.0.1:8443:8080 \
  -v "$(pwd)":/tls:ro \
  -e HTTPS_CERT_FILE=/tls/server.crt \
  -e HTTPS_KEY_FILE=/tls/server.key \
  dhi.io/go-httpbin:<tag>
$ curl -sk https://127.0.0.1:8443/get
```

### Deploy to Kubernetes

This manifest is the upstream Kustomize deployment with the image reference replaced. Replace `<tag>` with the image
tag, and add an `imagePullSecrets` entry if your cluster pulls from `dhi.io` with credentials:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
  labels:
    app.kubernetes.io/name: httpbin
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: httpbin
  template:
    metadata:
      labels:
        app.kubernetes.io/name: httpbin
    spec:
      containers:
        - name: httpbin
          image: dhi.io/go-httpbin:<tag>
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /status/200
              port: http
          readinessProbe:
            httpGet:
              path: /status/200
              port: http
          securityContext:
            runAsNonRoot: true
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app.kubernetes.io/name: httpbin
spec:
  selector:
    app.kubernetes.io/name: httpbin
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
      appProtocol: http
```

## Non-hardened images vs. Docker Hardened Images

- The upstream image's entrypoint is `/usr/bin/go-httpbin`. This image's entrypoint is `/usr/local/bin/go-httpbin`, a
  symlink to `/usr/bin/go-httpbin`. Both paths and `/bin/go-httpbin`, which the upstream README uses, resolve in every
  variant, so pass only flags as arguments: `docker run dhi.io/go-httpbin:<tag> -port 9090`.
- The upstream image sets the working directory to `/home/nonroot` and `SSL_CERT_FILE` in its environment. This image
  keeps the working directory at `/`, and only the Debian FIPS variants set `SSL_CERT_FILE`, as part of their OpenSSL
  FIPS configuration. go-httpbin reads no files from its working directory and makes no outbound TLS connections.

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

  **`go-httpbin` is an exception:** its FIPS variants run in the default FIPS 140 mode, which still allows the MD5
  digest algorithm on `/digest-auth` and the SHA-1 WebSocket handshake on `/websocket/echo`, because the HTTP protocols
  require them. Set `GODEBUG=fips140=only` on the container to refuse them; `/digest-auth` and `/websocket/echo` then
  fail while the other endpoints, such as `/get`, keep serving.

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
