## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this CloudNativePG image

This Docker Hardened CloudNativePG image includes:

- **manager**: The CloudNativePG operator manager binary that runs as a Kubernetes controller to manage PostgreSQL
  clusters
- **kubectl-cnpg**: The kubectl plugin for CloudNativePG that provides CLI commands for managing PostgreSQL clusters

## Start a CloudNativePG image

CloudNativePG is a Kubernetes operator that must be deployed in a Kubernetes cluster. The operator runs as a Deployment
and watches for CloudNativePG custom resources to manage PostgreSQL clusters.

### Basic Kubernetes deployment

Deploy the CloudNativePG operator using the official Helm chart or Kubernetes manifests. Replace the operator image with
the Docker Hardened Image:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudnative-pg-operator
  namespace: cloudnative-pg-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudnative-pg-operator
  template:
    metadata:
      labels:
        app: cloudnative-pg-operator
    spec:
      serviceAccountName: cloudnative-pg-operator
      containers:
        - name: manager
          image: dhi.io/cloudnative-pg:<tag>
          imagePullPolicy: Always
          command:
            - /manager
          env:
            - name: OPERATOR_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
```

### Using Helm chart

Install the CloudNativePG operator using Helm and override the image:

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm install cnpg \
  --namespace cloudnative-pg-system \
  --create-namespace \
  cnpg/cloudnative-pg \
  --set image.repository=dhi.io/cloudnative-pg \
  --set image.tag=<tag>
```

### Verify the operator

Check that the operator is running:

```bash
kubectl get pods -n cloudnative-pg-system
kubectl logs -n cloudnative-pg-system -l app=cloudnative-pg-operator
```

### Using kubectl-cnpg plugin

The `kubectl-cnpg` binary is included in the image. To use it as a kubectl plugin, copy it to your PATH:

```bash
docker run --rm dhi.io/cloudnative-pg:<tag> \
  cat /usr/local/bin/kubectl-cnpg > kubectl-cnpg
chmod +x kubectl-cnpg
sudo mv kubectl-cnpg /usr/local/bin/
```

Verify the plugin is installed:

```bash
kubectl cnpg version
kubectl cnpg --help
```

## Common CloudNativePG use cases

### Basic PostgreSQL cluster

Create a simple PostgreSQL cluster with one primary and two standby instances:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
spec:
  instances: 3
  postgresql:
    parameters:
      max_connections: "200"
  storage:
    size: 1Gi
```

Apply the cluster:

```bash
kubectl apply -f postgres-cluster.yaml
```

Monitor the cluster status:

```bash
kubectl get cluster postgres-cluster
kubectl cnpg status postgres-cluster
```

### PostgreSQL cluster with persistence

Create a PostgreSQL cluster with persistent storage and backup configuration:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster-persistent
spec:
  instances: 3
  postgresql:
    parameters:
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
  storage:
    size: 10Gi
    storageClass: fast-ssd
  backup:
    barmanObjectStore:
      destinationPath: s3://my-backup-bucket/postgres
      s3Credentials:
        accessKeyId:
          name: backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-credentials
          key: SECRET_ACCESS_KEY
      wal:
        retention: "7d"
      data:
        retention: "30d"
```

### PostgreSQL cluster with custom configuration

Create a PostgreSQL cluster with custom PostgreSQL parameters and resource limits:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster-custom
spec:
  instances: 2
  postgresql:
    parameters:
      max_connections: "100"
      shared_buffers: "128MB"
      work_mem: "4MB"
      maintenance_work_mem: "64MB"
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
  storage:
    size: 5Gi
```

### PostgreSQL cluster with TLS/SSL

Create a PostgreSQL cluster with TLS encryption enabled:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster-tls
spec:
  instances: 3
  postgresql:
    parameters:
      ssl: "on"
      ssl_cert_file: "/etc/postgresql/tls/tls.crt"
      ssl_key_file: "/etc/postgresql/tls/tls.key"
  certificates:
    serverTLSSecret: postgres-tls-cert
    serverCASecret: postgres-ca-cert
  storage:
    size: 1Gi
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
