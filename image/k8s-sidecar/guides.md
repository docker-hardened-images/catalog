## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this k8s-sidecar image

This Docker Hardened k8s-sidecar image includes:

- `sidecar.py` - Main Python script that collects ConfigMaps and Secrets
- Health endpoint server (`/healthz` on port 8080)
- Kubernetes client libraries for watching ConfigMaps and Secrets

## Start a k8s-sidecar image

k8s-sidecar is designed to run as a sidecar container in a Kubernetes pod. It requires access to the Kubernetes API and
a shared volume with the main application container.

### Basic usage in Kubernetes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
spec:
  containers:
    - name: main-app
      image: <your-main-app-image>
      volumeMounts:
        - name: config
          mountPath: /etc/config
    - name: k8s-sidecar
      image: dhi.io/k8s-sidecar:<tag>
      env:
        - name: LABEL
          value: "sidecar-config"
        - name: FOLDER
          value: "/etc/config"
      volumeMounts:
        - name: config
          mountPath: /etc/config
  volumes:
    - name: config
      emptyDir: {}
```

### Environment variables

| Variable            | Description                                        | Default                        | Required |
| ------------------- | -------------------------------------------------- | ------------------------------ | -------- |
| `LABEL`             | Label key used for filtering ConfigMaps/Secrets    | -                              | Yes      |
| `LABEL_VALUE`       | Value for the label filter                         | -                              | No       |
| `FOLDER`            | Folder where files should be placed                | `/etc/config`                  | No       |
| `FOLDER_ANNOTATION` | Annotation key for target directory override       | `k8s-sidecar-target-directory` | No       |
| `RESOURCE`          | Resource type to watch (`configmap` or `secret`)   | `configmap`                    | No       |
| `METHOD`            | Method for watching (`SLEEP` or `WATCH`)           | `SLEEP`                        | No       |
| `REQ_URL`           | URL to call after ConfigMap/Secret changes         | -                              | No       |
| `REQ_METHOD`        | HTTP method for REQ_URL                            | `GET`                          | No       |
| `HEALTH_PORT`       | Port for health endpoint                           | `8080`                         | No       |
| `LOG_LEVEL`         | Logging level (DEBUG, INFO, WARN, ERROR, CRITICAL) | `INFO`                         | No       |
| `LOG_FORMAT`        | Log format (JSON or LOGFMT)                        | `JSON`                         | No       |

### Example with Docker Compose (for local testing)

```yaml
version: '3.8'
services:
  app:
    image: <your-main-app-image>
    volumes:
      - config:/etc/config
  sidecar:
    image: dhi.io/k8s-sidecar:<tag>
    environment:
      - LABEL=sidecar-config
      - FOLDER=/etc/config
      - KUBECONFIG=/kube/config
    volumes:
      - config:/etc/config
      - kube-config:/kube
volumes:
  config:
  kube-config:
```

## Common k8s-sidecar use cases

### Basic ConfigMap collection

Collect ConfigMaps labeled with `sidecar-config` and store files in `/etc/config`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  labels:
    sidecar-config: "true"
data:
  config.yaml: |
    key: value
    setting: enabled
---
apiVersion: v1
kind: Pod
metadata:
  name: app-with-config
spec:
  containers:
    - name: app
      image: <your-app-image>
      volumeMounts:
        - name: config
          mountPath: /etc/config
    - name: sidecar
      image: dhi.io/k8s-sidecar:<tag>
      env:
        - name: LABEL
          value: "sidecar-config"
        - name: LABEL_VALUE
          value: "true"
        - name: FOLDER
          value: "/etc/config"
      volumeMounts:
        - name: config
          mountPath: /etc/config
  volumes:
    - name: config
      emptyDir: {}
```

### Collecting Secrets

Collect Secrets instead of ConfigMaps:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets
spec:
  containers:
    - name: app
      image: <your-app-image>
      volumeMounts:
        - name: secrets
          mountPath: /etc/secrets
    - name: sidecar
      image: dhi.io/k8s-sidecar:<tag>
      env:
        - name: LABEL
          value: "sidecar-secret"
        - name: RESOURCE
          value: "secret"
        - name: FOLDER
          value: "/etc/secrets"
      volumeMounts:
        - name: secrets
          mountPath: /etc/secrets
  volumes:
    - name: secrets
      emptyDir: {}
```

### Using health endpoint for readiness and liveness probes

The sidecar provides a health endpoint at `/healthz` that can be used for Kubernetes probes:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-health-checks
spec:
  containers:
    - name: app
      image: <your-app-image>
      volumeMounts:
        - name: config
          mountPath: /etc/config
    - name: sidecar
      image: dhi.io/k8s-sidecar:<tag>
      env:
        - name: LABEL
          value: "sidecar-config"
        - name: FOLDER
          value: "/etc/config"
        - name: HEALTH_PORT
          value: "8080"
      volumeMounts:
        - name: config
          mountPath: /etc/config
      readinessProbe:
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 20
        periodSeconds: 5
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 35
        periodSeconds: 10
  volumes:
    - name: config
      emptyDir: {}
```

### Triggering webhooks on ConfigMap changes

Configure the sidecar to call a webhook URL when ConfigMaps change:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-webhook
spec:
  containers:
    - name: app
      image: <your-app-image>
      volumeMounts:
        - name: config
          mountPath: /etc/config
    - name: sidecar
      image: dhi.io/k8s-sidecar:<tag>
      env:
        - name: LABEL
          value: "sidecar-config"
        - name: FOLDER
          value: "/etc/config"
        - name: REQ_URL
          value: "http://app:8080/reload"
        - name: REQ_METHOD
          value: "POST"
        - name: METHOD
          value: "WATCH"
      volumeMounts:
        - name: config
          mountPath: /etc/config
  volumes:
    - name: config
      emptyDir: {}
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

- FIPS variants include fips in the variant name and tag. They come in both runtime and build-time variants. These
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
