## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This guide provides practical examples for using the dapr-daprd Docker Hardened Image to run the Dapr runtime sidecar
alongside your applications.

## Image contents

This Docker Hardened dapr-daprd image includes:

- The `daprd` binary built from the official Dapr releases
- The entrypoint is the `daprd` binary at `/usr/local/bin/daprd`
- An upstream-compatible `/daprd` symlink for manifests that override the command
- No default configuration - daprd is designed to be configured via command-line flags or config files

## Start a dapr-daprd container

```bash
docker run -d --name daprd \
    -p 3500:3500 \
    -p 50001:50001 \
    dhi.io/dapr-daprd:<tag> \
    --app-id myapp \
    --dapr-http-port 3500 \
    --dapr-grpc-port 50001
```

This starts daprd with:

- HTTP API on port 3500
- gRPC API on port 50001
- App ID of "myapp"

## Common use cases

### Run with Docker Compose

```bash
cat <<EOF > docker-compose.yaml
services:
  app:
    image: your-app:latest
    ports:
      - "8080:8080"
    depends_on:
      - daprd

  daprd:
    image: dhi.io/dapr-daprd:<tag>
    command: [
      "--app-id", "myapp",
      "--app-port", "8080",
      "--dapr-http-port", "3500",
      "--dapr-grpc-port", "50001",
      "--log-level", "info"
    ]
    ports:
      - "3500:3500"
      - "50001:50001"
    network_mode: "service:app"
EOF
```

Start the stack:

```bash
docker compose up -d
```

### Run daprd as sidecar to an application container

Create a Docker network for the sidecar pattern:

```bash
docker network create myapp-network
```

Start your application:

```bash
docker run -d --name myapp \
    --network myapp-network \
    -p 8080:8080 \
    your-app:latest
```

Start daprd as a sidecar:

```bash
docker run -d --name daprd \
    --network myapp-network \
    -p 3500:3500 \
    -p 50001:50001 \
    dhi.io/dapr-daprd:<tag> \
    --app-id myapp \
    --app-port 8080 \
    --dapr-http-port 3500 \
    --dapr-grpc-port 50001 \
    --log-level info
```

Your application can now access Dapr APIs at `http://localhost:3500` (HTTP) or `localhost:50001` (gRPC).

### Configuration files and supported flags

For component, subscription, and configuration file layouts, follow the current upstream Dapr runtime documentation at
[dapr.io](https://docs.dapr.io/). Dapr changes supported flags over time, so this guide intentionally avoids hard-coding
advanced configuration flags beyond the basic startup patterns above.

### Kubernetes deployment with sidecar injection

To use the dapr-daprd hardened image in Kubernetes, you can either use Dapr's automatic sidecar injection or manually
configure the sidecar.

#### Manual sidecar configuration

Create a deployment with daprd as a sidecar container:

```bash
cat <<EOF > app-with-dapr.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: your-app:latest
          ports:
            - containerPort: 8080
              name: http
        - name: daprd
          image: dhi.io/dapr-daprd:<tag>
          args:
            - "--app-id"
            - "myapp"
            - "--app-port"
            - "8080"
            - "--dapr-http-port"
            - "3500"
            - "--dapr-grpc-port"
            - "50001"
            - "--log-level"
            - "info"
          ports:
            - containerPort: 3500
              name: dapr-http
            - containerPort: 50001
              name: dapr-grpc
            - containerPort: 9090
              name: metrics
      imagePullSecrets:
        - name: <your-registry-secret>
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: default
spec:
  ports:
    - port: 8080
      targetPort: 8080
      name: http
    - port: 3500
      targetPort: 3500
      name: dapr-http
  selector:
    app: myapp
EOF
```

Apply the manifest:

```bash
kubectl apply -f app-with-dapr.yaml
```

Verify the deployment:

```console
$ kubectl get pods -n default
NAME                     READY   STATUS    RESTARTS   AGE
myapp-6959756cc4-bbkp9   2/2     Running   0          38s
```

Access the Dapr sidecar:

```console
$ kubectl port-forward -n default deployment/myapp 3500:3500
$ curl http://localhost:3500/v1.0/healthz
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened daprd (daprio/daprd) | Docker Hardened dapr-daprd                                           |
| --------------- | --------------------------------- | -------------------------------------------------------------------- |
| Base image      | Debian Slim                       | Debian 13 hardened base                                              |
| Security        | Standard image                    | Hardened build with security patches and security metadata           |
| Shell access    | Shell available                   | No shell                                                             |
| Package manager | Package manager available         | No package manager                                                   |
| User            | Runs as root by default           | Runs as nonroot user (UID 65532)                                     |
| Binary location | `/daprd`                          | `/daprd` compatibility symlink and `/usr/local/bin/daprd` entrypoint |
| Attack surface  | Standard utilities included       | Only daprd binary, no additional utilities                           |
| Debugging       | Shell and utilities available     | Use Docker Debug or image mount for troubleshooting                  |
| CVE compliance  | Standard vulnerability patching   | Near-zero CVEs with proactive remediation                            |
| Provenance      | Not signed                        | Signed provenance with complete SBOM/VEX                             |

### Entrypoint difference

**Important:** The DHI dapr-daprd image provides an entrypoint while the upstream daprio/daprd image does not. This is
an intentional usability improvement that follows container best practices.

**Upstream (daprio/daprd):** No entrypoint defined. Users must specify the binary path:

```bash
# Upstream requires specifying the binary path
docker run daprio/daprd:1.17.3 /daprd --help
docker run daprio/daprd:1.17.3 /daprd --app-id myapp --dapr-http-port 3500
```

**DHI (dhi.io/dapr-daprd):** Entrypoint is `/usr/local/bin/daprd`, and the image also preserves the upstream `/daprd`
path for compatibility with manifests that override the command:

```bash
# DHI allows direct usage without specifying binary path
docker run dhi.io/dapr-daprd:<tag> --help
docker run dhi.io/dapr-daprd:<tag> --app-id myapp --dapr-http-port 3500
```

**In Kubernetes:** The DHI entrypoint simplifies pod configuration:

```yaml
# Upstream requires command override
spec:
  containers:
  - name: daprd
    image: daprio/daprd:1.17.3
    command: ["/daprd"]
    args: ["--app-id", "myapp"]

# DHI also works with command override because /daprd is preserved
spec:
  containers:
  - name: daprd
    image: dhi.io/dapr-daprd:<tag>
    command: ["/daprd"]
    args: ["--app-id", "myapp"]
```

**Why this matters:** Providing an entrypoint keeps the common `docker run` experience simple, while preserving `/daprd`
avoids breaking existing manifests and command overrides that were written for the upstream image.

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```console
$ docker debug daprd
```

Or mount debugging tools with the image mount feature:

```console
$ docker run --rm -it --pid container:daprd \
    --mount=type=image,source=dhi.io/busybox:<tag>,destination=/dbg,ro \
    dhi.io/dapr-daprd:<tag> /dbg/bin/sh
```

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

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                               |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                               |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   If you're using a multi-stage build, update the runtime stage to use a non-dev hardened image. This ensures your
   production containers run with minimal attack surface.

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
