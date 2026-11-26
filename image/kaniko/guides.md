## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kaniko:1`
- Mirrored image: `<your-namespace>/dhi-kaniko:1`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

kaniko builds container images from a Dockerfile without a Docker daemon. It extracts the base image over its own root
filesystem, runs each instruction, snapshots the changes, and pushes the result to a registry. This image packages the
maintained fork of the archived Google project. The full flag reference is at
https://github.com/chainguard-forks/kaniko.

The Debian 13 runtime tag is `dhi.io/kaniko:1.25.23-debian13`. The shorter tags `1`, `1.25`, and `1.25.23` point to it.
The Alpine 3.24 runtime tag is `dhi.io/kaniko:1.25.23-alpine3.24`, also published as `1-alpine`. Add `-dev`, `-fips`, or
`-fips-dev` for the other variants, for example `1-dev` or `1-alpine-fips`.

## Start a kaniko image

The entrypoint is `/kaniko/executor`, and the image sets no command, so arguments that you pass to `docker run` are
executor flags. The working directory is `/workspace`. Mount your build context there.

### Basic usage

```bash
docker run --rm dhi.io/kaniko:1 version
```

The output is `Kaniko version :  v1.25.23`.

### Build an image to a tarball

The examples in this guide build this Dockerfile. Save it as `Dockerfile` in an empty directory, and run the commands
from that directory.

```dockerfile
FROM alpine:3.22
RUN echo "built by kaniko" > /hello.txt
CMD ["cat", "/hello.txt"]
```

Build the image and save it as a tarball, without pushing it. `--tar-path` names the image after `--destination`.

```bash
docker run --rm -v "$PWD":/workspace dhi.io/kaniko:1 \
  --context dir:///workspace \
  --dockerfile Dockerfile \
  --destination kaniko-demo:1 \
  --no-push \
  --tar-path /workspace/kaniko-demo.tar
docker load -i kaniko-demo.tar
docker run --rm kaniko-demo:1
```

The last command prints `built by kaniko`. kaniko runs as root, so root owns `kaniko-demo.tar` on the host.

### Push to a registry

This example starts a local registry on a Docker network and pushes to it. `--insecure` allows a push over plain HTTP.
Use it only for a local test registry like this one.

```bash
docker network create kaniko-demo
docker run -d --name registry --network kaniko-demo dhi.io/distribution-registry:3
docker run --rm --network kaniko-demo -v "$PWD":/workspace dhi.io/kaniko:1 \
  --context dir:///workspace \
  --dockerfile Dockerfile \
  --destination registry:5000/kaniko-demo:1 \
  --insecure
```

kaniko prints `Pushed registry:5000/kaniko-demo@sha256:...` when the push succeeds.

### Registry credentials

kaniko reads registry credentials from `/kaniko/.docker/config.json`. The `auth` value is the base64 encoding of
`username:password`.

```json
{
  "auths": {
    "registry.example.com": {
      "auth": "<base64 of username:password>"
    }
  }
}
```

Mount the file read-only at that path, for example with `-v "$HOME/kaniko/config.json":/kaniko/.docker/config.json:ro`
on `docker run`, or from a Secret as in the Kubernetes example below. Keep it outside the build context so that a `COPY`
step can't pick it up.

Don't mount a host `config.json` that relies on a `credsStore` such as `desktop` or `osxkeychain`. Those helpers aren't
in the image, so the push fails with `exec: "docker-credential-desktop": executable file not found in $PATH`. The image
includes the `docker-credential-gcr`, `docker-credential-ecr-login`, and `docker-credential-acr-env` helpers in
`/kaniko`, which is on `PATH`. Select one per registry with `credHelpers`, for example
`{"credHelpers": {"123456789012.dkr.ecr.us-east-1.amazonaws.com": "ecr-login"}}`.

### Trust a private CA

This example pushes to a registry whose TLS certificate the image doesn't trust. It creates a self-signed certificate in
`$HOME/kaniko`, outside the build context, starts a TLS registry with it on the `kaniko-demo` network from the previous
example, and passes the certificate to kaniko with `--registry-certificate`. The key is made world-readable because the
registry runs as a non-root user; do this only for a throwaway test key.

```bash
mkdir -p "$HOME/kaniko"
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 30 \
  -subj "/CN=registry-tls" -addext "subjectAltName=DNS:registry-tls" \
  -keyout "$HOME/kaniko/registry.key" -out "$HOME/kaniko/ca.crt"
chmod 0644 "$HOME/kaniko/registry.key"
docker run -d --name registry-tls --network kaniko-demo \
  -v "$HOME/kaniko":/certs:ro \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/ca.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  dhi.io/distribution-registry:3
docker run --rm --network kaniko-demo -v "$PWD":/workspace \
  -v "$HOME/kaniko/ca.crt":/kaniko/certs/ca.crt:ro \
  dhi.io/kaniko:1 \
  --context dir:///workspace \
  --dockerfile Dockerfile \
  --destination registry-tls:5443/kaniko-demo:1 \
  --registry-certificate registry-tls:5443=/kaniko/certs/ca.crt
```

kaniko prints `Pushed registry-tls:5443/kaniko-demo@sha256:...`. Without the certificate, the push fails with
`x509: certificate signed by unknown authority`.

`--registry-certificate` trusts the certificate for one registry, named as in `--destination`. To trust it for every
registry, mount it into `/kaniko/ssl/certs/` instead, for example with
`-v "$HOME/kaniko/ca.crt":/kaniko/ssl/certs/my-ca.crt:ro`, and drop the flag. Don't use either for a registry whose
certificate chains to a public CA, which the image already trusts.

### Cache base images

The base-image cache warmer, `/kaniko/warmer`, is only in the `-dev` tags. Neither upstream nor this image creates
`/cache`, the default `--cache-dir`, so mount a volume there.

```bash
docker run --rm --entrypoint /kaniko/warmer -v kaniko-cache:/cache dhi.io/kaniko:1-dev \
  --cache-dir=/cache --image=alpine:3.22
```

To use the cache, mount the same volume at `/cache` when you run the executor and pass `--cache=true`. That flag also
turns on layer caching in a registry repository, `<destination>/cache` by default. In kaniko 1.25.23, as in upstream
1.24.0, pushing an image whose base came from the warmer cache to a Distribution 3 registry fails with
`MANIFEST_INVALID`.

### Run kaniko in Kubernetes

kaniko runs as root, UID 0, and doesn't need a privileged container. The restricted Pod Security Standard forbids
`runAsUser: 0`, so run the Job in a namespace that enforces `baseline` or lower. This example mounts the credentials
Secret at `/kaniko/.docker` and builds from a Git repository:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kaniko-docker-config
stringData:
  config.json: |
    {"auths": {"registry.example.com": {"auth": "<base64 of username:password>"}}}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: kaniko-build
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: kaniko
          image: dhi.io/kaniko:1
          args:
            - --context=git://github.com/<your-org>/<your-repo>.git#refs/heads/main
            - --dockerfile=Dockerfile
            - --destination=registry.example.com/team/app:1
          securityContext:
            runAsUser: 0
          volumeMounts:
            - name: docker-config
              mountPath: /kaniko/.docker
              readOnly: true
      volumes:
        - name: docker-config
          secret:
            secretName: kaniko-docker-config
```

### Use a `-dev` tag in a CI job with a shell

CI systems that run a script inside the job image need a shell, so use a `-dev` tag and clear the entrypoint. This
GitLab CI job writes the credentials and then runs the executor:

```yaml
build-image:
  image:
    name: dhi.io/kaniko:1-dev
    entrypoint: [""]
  script:
    - printf '{"auths":{"%s":{"auth":"%s"}}}' "$CI_REGISTRY" "$(printf '%s:%s' "$CI_REGISTRY_USER" "$CI_REGISTRY_PASSWORD" | base64 | tr -d '\n')" > /kaniko/.docker/config.json
    - /kaniko/executor --context "dir://$CI_PROJECT_DIR" --dockerfile "$CI_PROJECT_DIR/Dockerfile" --destination "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA"
```

Make the executor the last command. During a build, kaniko extracts each stage's base image over `/` and deletes it
between stages, including the `/bin` and `/usr` of the `-dev` image. The shell that started the executor keeps running,
but later commands in the same container run whatever the build left behind. After a build whose last stage is
`FROM scratch`, `ls` and the package manager fail with `command not found`.

## Non-hardened images vs. Docker Hardened Images

The runtime tags match `gcr.io/kaniko-project/executor:latest`: the same entrypoint, the same paths (`/kaniko/executor`,
`/kaniko/.docker`, `/workspace`, `/kaniko/ssl/certs`), the same environment, and the root user. Commands and manifests
written for that image work unchanged. The differences are:

| Item           | `gcr.io/kaniko-project/executor`                             | `dhi.io/kaniko`                                                                                                                  |
| -------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| User           | root                                                         | root on every variant, including runtime and FIPS                                                                                |
| Debug shell    | `:debug` adds busybox in a `/busybox` volume                 | `-dev` tags add the distro shell at `/bin/bash` and `/bin/sh`, coreutils, findutils, and `apk` or `apt`. There is no `/busybox`. |
| Cache warmer   | `:debug` and `gcr.io/kaniko-project/warmer`                  | `/kaniko/warmer` in the `-dev` tags only                                                                                         |
| `/kaniko` mode | `0777`                                                       | `1777`, world-writable with the sticky bit                                                                                       |
| Base           | `scratch`                                                    | Alpine 3.24 or Debian 13 files such as `/etc/os-release` and time zone data                                                      |
| Flavors        | `slim` tags                                                  | No `slim` flavor                                                                                                                 |
| Platforms      | `linux/amd64`, `linux/arm64`, `linux/s390x`, `linux/ppc64le` | `linux/amd64` and `linux/arm64`                                                                                                  |

- **Root user:** kaniko unpacks base image layers over the container's own root filesystem, sets file ownership, and
  runs `RUN` steps as the users that your Dockerfile names. That needs root, so every variant runs as root, unlike most
  Docker Hardened Images. Don't set a non-root user for this image.
- **Distro base:** the first build stage's `RUN` steps can see files from the image's Alpine or Debian base that the
  build's own base image doesn't replace, for example `/etc/os-release` under a `busybox` base. These files aren't added
  to the image that kaniko produces unless a `RUN` step changes them.

## FIPS variants

- The `-fips` and `-fips-dev` tags build the executor, the credential helpers, and the `-fips-dev` warmer with the Go
  FIPS 140-3 module (`GOFIPS140=v1.0.0`). The default runtime setting is `fips140=on`, so registry TLS uses the FIPS
  module.
- The FIPS images also include the OpenSSL FIPS provider.
- Registry TLS must use FIPS-approved algorithms. A registry certificate with a 1024-bit RSA key fails with
  `tls: no FIPS compatible certificate chains found`. RSA 2048-bit and ECDSA P-256 certificates work. Use
  `--registry-certificate` for a private CA, as in the standard tags.
- The default `fips140=on` setting works with every `--snapshot-mode` and with `--cache=true`. Under the strict
  `GODEBUG=fips140=only` setting, `--snapshot-mode=redo` and `--snapshot-mode=time` abort with
  `crypto/md5: use of MD5 is not allowed in FIPS 140-only mode`, and so does `--cache=true` when the Dockerfile has a
  `COPY` step. In strict mode, keep the default `--snapshot-mode=full` and don't use `--cache`:

```bash
docker run --rm -e GODEBUG=fips140=only -v "$PWD":/workspace dhi.io/kaniko:1-fips \
  --context dir:///workspace \
  --dockerfile Dockerfile \
  --destination kaniko-demo:1 \
  --no-push \
  --snapshot-mode=full
```

Debian 13 FIPS tags: `1.25.23-debian13-fips` (runtime) and `1.25.23-debian13-fips-dev` (dev). Alpine 3.24 FIPS tags:
`1.25.23-alpine3.24-fips` (runtime) and `1.25.23-alpine3.24-fips-dev` (dev).

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
