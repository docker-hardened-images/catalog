## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a cert-manager-istio-csr image

> **Note:** The cert-manager-istio-csr image is primarily designed to run inside a Kubernetes cluster as part of an
> Istio deployment with cert-manager. The standalone Docker command below simply displays configuration options.

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run --rm -it dhi.io/cert-manager-istio-csr:<tag> --help
```

### Configuration flags

cert-manager-istio-csr is configured using command-line flags. The following table lists the most commonly used flags:

| Flag                         | Description                                                          | Default           | Required |
| ---------------------------- | -------------------------------------------------------------------- | ----------------- | -------- |
| `--certificate-namespace`    | Namespace for certificate requests                                   | `istio-system`    | No       |
| `--issuer-name`              | Name of cert-manager Issuer/ClusterIssuer                            | `istio-ca`        | No       |
| `--issuer-kind`              | Kind of issuer (Issuer or ClusterIssuer)                             | `Issuer`          | No       |
| `--issuer-group`             | Group of issuer                                                      | `cert-manager.io` | No       |
| `--metrics-port`             | Port for Prometheus metrics                                          | `9402`            | No       |
| `--readiness-probe-port`     | Port for readiness probe                                             | `6060`            | No       |
| `--readiness-probe-path`     | Path for readiness probe                                             | `/readyz`         | No       |
| `--ca-trusted-node-accounts` | Service account names for trusted nodes (required for Istio Ambient) | -                 | No       |

For a complete list of available flags, run:

```bash
docker run --rm -it dhi.io/cert-manager-istio-csr:<tag> --help
```

## Common cert-manager-istio-csr use cases

### Basic Kubernetes deployment

Deploy cert-manager-istio-csr in a Kubernetes cluster with cert-manager installed:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-manager-istio-csr
  namespace: istio-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cert-manager-istio-csr
  template:
    metadata:
      labels:
        app: cert-manager-istio-csr
    spec:
      serviceAccountName: cert-manager-istio-csr
      containers:
      - name: istio-csr
        image: dhi.io/cert-manager-istio-csr:<tag>
        args:
        - --certificate-namespace=istio-system
        - --issuer-name=istio-ca
        - --metrics-port=9402
        - --readiness-probe-port=6060
        ports:
        - containerPort: 6060
          name: readiness-probe
        - containerPort: 9402
          name: metrics
        readinessProbe:
          httpGet:
            path: /readyz
            port: 6060
          initialDelaySeconds: 5
          periodSeconds: 10
```

### With Istio Ambient mode

When deploying in Istio Ambient mode, you must set the `--ca-trusted-node-accounts` flag with the
namespace/service-account-name of ztunnel:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-manager-istio-csr
  namespace: istio-system
spec:
  template:
    spec:
      containers:
      - name: istio-csr
        image: dhi.io/cert-manager-istio-csr:<tag>
        args:
        - --ca-trusted-node-accounts=istio-system/ztunnel
        ports:
        - containerPort: 6060
          name: readiness-probe
        - containerPort: 9402
          name: metrics
```

### With custom cert-manager issuer

Configure cert-manager-istio-csr to use a custom ClusterIssuer:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-manager-istio-csr
  namespace: istio-system
spec:
  template:
    spec:
      containers:
      - name: istio-csr
        image: dhi.io/cert-manager-istio-csr:<tag>
        args:
        - --issuer-name=my-custom-issuer
        - --issuer-kind=ClusterIssuer
        - --issuer-group=cert-manager.io
```

### Monitoring with Prometheus

Expose metrics endpoint for Prometheus scraping:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: cert-manager-istio-csr-metrics
  namespace: istio-system
  labels:
    app: cert-manager-istio-csr
spec:
  ports:
  - port: 9402
    targetPort: 9402
    name: metrics
  selector:
    app: cert-manager-istio-csr
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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

### Differences from upstream

When migrating from the upstream `quay.io/jetstack/cert-manager-istio-csr` image, note the following differences:

| Item              | Upstream                                 | Docker Hardened Image                 |
| :---------------- | :--------------------------------------- | :------------------------------------ |
| Entrypoint        | `/ko-app/cmd`                            | `/usr/local/bin/manager`              |
| Environment vars  | `KO_DATA_PATH=/var/run/ko` (ko-specific) | Not required (binary build)           |
| Configuration     | Command-line flags                       | Command-line flags (same as upstream) |
| Port declarations | None                                     | None (same as upstream)               |

The Docker Hardened Image uses a standard binary build process instead of the `ko` build tool used by upstream. This
results in a different entrypoint path, but the application functionality and configuration method (command-line flags)
remain identical.

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
