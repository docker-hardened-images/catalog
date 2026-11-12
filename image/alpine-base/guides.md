## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/alpine-base:<tag>`
- Mirrored image: `<your-namespace>/dhi-alpine-base:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Alpine Base image

This Docker Hardened alpine-base image provides a minimal, security-hardened Alpine Linux foundation built on Docker
Hardened Images/Alpine Linux v3.23:

- `busybox`: A single binary that provides lightweight implementations of common Unix utilities including `sh`, `ls`,
  `cp`, `mv`, `wget`, and more - all essential for shell scripting and container tooling
- `musl libc`: A lightweight, standards-compliant C standard library used as the foundation for all Alpine-based
  binaries
- `/bin/ash` and `/bin/sh`: POSIX-compatible shells provided by BusyBox, available in both the runtime and dev variants
- `apk` package manager: Available in the dev variant only (`-dev` tag) for installing additional packages during build
  stages - the runtime variant does not include `apk` to minimise attack surface
- Standard TLS certificates: Pre-installed CA certificate bundle at `/etc/ssl/certs/ca-certificates.crt` for secure
  outbound TLS connections without additional setup
- Pre-configured `nonroot` user (UID 65532) for running workloads without root privileges in the runtime variant

## Start an Alpine Base instance

On startup, the image initializes BusyBox and Alpine utilities.

Run the following command and replace `<tag>` with the image variant you want to run:

```console
$ docker run -it --rm dhi.io/alpine-base:<tag> sh
```

> **Note:** The runtime variant includes `/bin/ash` and a shell. To use the dev variant for build-time operations, use a
> tag that includes `-dev` (for example, `3.23-alpine3.23-dev`).

## Common Alpine Base use cases

### Minimal Container Operations

Use alpine-base as the foundation for lightweight, minimal containers.

Create a sample application and Dockerfile:

```bash
cat > myapp << 'EOF'
#!/bin/sh
echo "hello from alpine-base DHI"
EOF
chmod +x myapp

cat > Dockerfile << 'EOF'
FROM dhi.io/alpine-base:<tag>

COPY myapp /usr/local/bin/myapp
USER nonroot
CMD ["/usr/local/bin/myapp"]
EOF
```

Build and run:

```console
$ docker build -t alpine-base-minimal-test .
$ docker run --rm alpine-base-minimal-test
hello from alpine-base DHI
```

Verify the container runs as nonroot:

```console
$ docker inspect alpine-base-minimal-test --format='User: {{.Config.User}} | Cmd: {{.Config.Cmd}}'
User: nonroot | Cmd: [/usr/local/bin/myapp]

$ docker run --rm --entrypoint /bin/ash alpine-base-minimal-test -c 'id'
uid=65532(nonroot) gid=65532(nonroot) groups=65532(nonroot),65532(nonroot)
```

### Security Testing

Use the dev variant with apk to install testing tools in a build stage. Because `curl` is dynamically linked on Alpine
with a deep transitive library chain, copy the entire `/usr/lib` from the build stage rather than individual libraries —
this is safe because DHI's `/usr/lib` is already stripped to near-minimum.

Create the Dockerfile:

```bash
cat > Dockerfile.security-test << 'EOF'
FROM dhi.io/alpine-base:<tag>-dev AS build

RUN apk add --no-cache curl ca-certificates

FROM dhi.io/alpine-base:<tag>

COPY --from=build /usr/lib/                          /usr/lib/
COPY --from=build /usr/bin/curl                      /usr/bin/curl
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

USER nonroot
EOF
```

Build and verify:

```console
$ docker build -t alpine-base-security-test -f Dockerfile.security-test .

$ docker run --rm --entrypoint /usr/bin/curl alpine-base-security-test --version
curl 8.19.0 (aarch64-alpine-linux-musl) libcurl/8.19.0 OpenSSL/3.5.5 zlib/1.3.2 ...

$ docker run --rm --entrypoint /bin/ash alpine-base-security-test -c 'id'
uid=65532(nonroot) gid=65532(nonroot) groups=65532(nonroot),65532(nonroot)
```

> **Note:** Copying individual libraries is fragile on Alpine — `curl` has a deep transitive dependency chain (`libcurl`
> → `libssl`, `libcrypto`, `libnghttp2`, `libbrotli*`, `libzstd`, `libcares`, `libidn2`, `libpsl`, `libunistring`) that
> changes between versions. Copying `/usr/lib/` as a whole is the reliable approach. Verified against `curl 8.19.0-r0`
> on Alpine 3.23 (`aarch64`).

### Base for Custom Applications

Use the dev variant to build your application, then copy the statically compiled binary to the runtime image. This
example uses Go with `CGO_ENABLED=0` to produce a static binary that requires no shared libraries.

Create the application and Dockerfile:

```bash
mkdir -p goapp

cat > goapp/main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("hello from alpine-base DHI")
}
EOF

cat > goapp/go.mod << 'EOF'
module server

go 1.21
EOF

cat > goapp/Dockerfile << 'EOF'
FROM dhi.io/alpine-base:<tag>-dev AS build

RUN apk add --no-cache go
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o server .

FROM dhi.io/alpine-base:<tag>
COPY --from=build /app/server /usr/local/bin/server
USER nonroot
CMD ["/usr/local/bin/server"]
EOF
```

Build and run:

```console
$ docker build -t alpine-base-go-test goapp/
$ docker run --rm alpine-base-go-test
hello from alpine-base DHI
```

Verify the binary runs as nonroot:

```console
$ docker run --rm --entrypoint /bin/ash alpine-base-go-test -c 'id'
uid=65532(nonroot) gid=65532(nonroot) groups=65532(nonroot),65532(nonroot)
```

### Deploy Alpine Base in Kubernetes

For authentication setup, see [Use a Docker Hardened Image in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/).

Create the namespace and imagePullSecret:

```console
$ kubectl create namespace alpine-base-test

$ kubectl create secret docker-registry dhi-registry-secret \
    --docker-server=dhi.io \
    --docker-username=<your-docker-username> \
    --docker-password=<your-access-token> \
    --namespace=alpine-base-test
```

Write the Deployment manifest:

```bash
cat > alpine-base-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpine-base-deployment
  namespace: alpine-base-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alpine-base
  template:
    metadata:
      labels:
        app: alpine-base
    spec:
      imagePullSecrets:
        - name: dhi-registry-secret
      containers:
        - name: alpine-base
          image: dhi.io/alpine-base:<tag>
          securityContext:
            runAsNonRoot: true
      nodeSelector:
        kubernetes.io/os: linux
EOF
```

Deploy and verify:

```console
$ kubectl apply -f alpine-base-deployment.yaml
$ kubectl get pods -n alpine-base-test
```

> **Note:** The runtime image runs as the `nonroot` user (UID 65532) by default. The deployment uses
> `runAsNonRoot: true` to enforce this. If your workload requires root, set `runAsUser: 0` explicitly, but this is not
> recommended for production.

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature             | DOI (`library/alpine`) | DHI (`dhi.io/alpine-base`)                                     |
| :------------------ | :--------------------- | :------------------------------------------------------------- |
| User                | root                   | `nonroot` / UID 65532 (runtime) / `root` (dev)                 |
| Shell               | `/bin/ash`             | `/bin/ash` (runtime) / `/bin/ash` (dev)                        |
| Package manager     | `apk`                  | No (runtime) / `apk` (dev)                                     |
| Entrypoint          | `/bin/sh`              | None (CMD-only)                                                |
| Uncompressed size   | ~5MB                   | ~4MB                                                           |
| Zero CVE commitment | No                     | Yes                                                            |
| FIPS variant        | No                     | Yes (FIPS + STIG + CIS)                                        |
| Base OS             | Alpine Linux           | Docker Hardened Images/Alpine Linux v3.23                      |
| Compliance labels   | None                   | CIS (runtime), FIPS+STIG+CIS (fips)                            |
| ENV: PATH           | `/usr/sbin:/sbin:/bin` | `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- **Runtime variants** — designed for production use. These images:

  - Run as the `nonroot` user (UID 65532) by default
  - Include `/bin/ash` and `/bin/sh`
  - Do **not** include a package manager (`apk`)
  - Contain only the minimal set of libraries needed to run the app

- **Dev variants** (tag includes `-dev`) — intended for use in build stages of a multi-stage Dockerfile. These images:

  - Run as the `root` user
  - Include `/bin/ash`, `/bin/sh`, and the `apk` package manager (`apk-tools 3.0.5-r0`)
  - Are used to build, compile, or install application dependencies

- **FIPS variants** (tag includes `-fips`) — for environments requiring FIPS 140 compliance. Available in both runtime
  and dev flavours. These images carry CIS, FIPS, and STIG (100%) compliance badges.

The following tags are available for Alpine 3.23:

| Variant      | Tags                                        | User      | Compliance      | Support until |
| :----------- | :------------------------------------------ | :-------- | :-------------- | :------------ |
| Runtime      | `3.23-alpine3.23`, `3.23`                   | `nonroot` | CIS             | Nov 2027      |
| Dev          | `3.23-alpine3.23-dev`, `3.23-dev`           | `root`    | CIS             | Nov 2027      |
| FIPS runtime | `3.23-alpine3.23-fips`, `3.23-fips`         | `nonroot` | CIS, FIPS, STIG | Nov 2027      |
| FIPS dev     | `3.23-alpine3.23-fips-dev`, `3.23-fips-dev` | `root`    | CIS, FIPS, STIG | Nov 2027      |

> **Note:** Pulling FIPS variants requires a Docker subscription.

To view all available tags, select the **Tags** tab for this repository.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                          |
| :----------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                               |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                             |
| Non-root user      | By default, runtime images run as the `nonroot` user (UID 65532). Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                       |
| Multi-stage build  | Use images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                  |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                      |
| Ports              | Runtime images run as the `nonroot` user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | The DHI alpine-base image has no configured entrypoint (unlike some Docker Official Images that default to `/bin/sh`). Use `CMD` to specify your application command, or inspect the entry point with `docker inspect` and update your Dockerfile if necessary.                                                         |
| Shell              | The runtime image includes `/bin/ash`. However, the runtime image does not include a package manager. Use `dev` images in build stages to install packages and copy artifacts to the runtime stage.                                                                                                                     |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, use a multi-stage build. All stages in your Dockerfile
   should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your final runtime
   stage should use a non-dev image variant.

1. **Install additional packages.**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` have package managers. Use a multi-stage Dockerfile to install packages in the build
   stage using a `dev` image, then copy only the necessary artifacts to the runtime stage.

   For Alpine-based images, use `apk` to install packages in the dev stage. For Debian-based images, use `apt-get`.

## Troubleshoot migration

### General debugging

The recommended method for debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default, runtime image variants run as the `nonroot` user (UID 65532). Ensure that necessary files and directories
are accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application can access them.

### Privileged ports

Runtime images run as the `nonroot` user by default. As a result, applications in these images can't bind to privileged
ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

To avoid issues, configure your application to listen on port 1025 or higher inside the container, even if you map it to
a lower port on the host. For example, `docker run -p 80:8080 my-image` works because the port inside the container is
8080, but `docker run -p 80:81 my-image` won't because the port inside the container is 81.

### Shell

The runtime image includes `/bin/ash`. However, the runtime image does not include a package manager. Use `dev` images
in build stages to install packages with `apk`, then copy any necessary artifacts into the runtime stage. To debug a
running container interactively, use Docker Debug.

### Entry point

The DHI alpine-base image has no configured entrypoint. Use `docker inspect` to confirm:

```console
$ docker inspect --format='{{json .Config.Entrypoint}}' dhi.io/alpine-base:<tag>
null
```

If your application previously relied on an entrypoint being set by the base image, add an explicit `ENTRYPOINT`
instruction to your Dockerfile.
