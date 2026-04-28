## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/k8ssandra-medusa:<tag>`
- Mirrored image: `<your-namespace>/dhi-k8ssandra-medusa:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## About K8ssandra Medusa

K8ssandra Medusa is the backup and restore component of the K8ssandra project. It is **not** intended to be run as a
standalone Docker container: the image runs a Medusa gRPC server that the `k8ssandra-operator` deploys as a sidecar in
each Cassandra pod, plus a `medusa-restore` init container that handles in-place restores at pod startup. Backups,
restores, and verifications are driven through K8ssandra custom resources (`MedusaBackupJob`, `MedusaBackupSchedule`,
`MedusaRestoreJob`).

Configuring Medusa therefore happens in two places:

- The `medusa` block of a `K8ssandraCluster` resource (or the `cassandra.medusa` Helm values for the
  `k8ssandra-operator` chart), which selects the Medusa container image, storage backend, and credentials.
- A `MedusaBackupJob` (or schedule) resource that asks the operator to take a backup of a specific
  `CassandraDatacenter`.

The Docker Hardened image is a drop-in replacement for `k8ssandra/medusa`. You enable it by setting the
`spec.medusa.containerImage` fields on a `K8ssandraCluster` to point at this image.

## Prerequisites

Before using this image, you need:

- A Kubernetes cluster (version 1.21 or later)
- `kubectl` configured to access your cluster
- `k8ssandra-operator` and `cass-operator` already installed in the cluster
- Object storage Medusa can write to (S3, GCS, Azure, or an S3-compatible endpoint such as MinIO)
- A Kubernetes `Secret` containing credentials for that storage backend

For installing the operator with Docker Hardened Images, see the `k8ssandra-operator` and `k8ssandra-cass-operator`
guides in this catalog.

## Deploy K8ssandra with Medusa enabled

### Create the storage credentials secret

Medusa expects a Kubernetes `Secret` whose `credentials` key contains the AWS-style INI credentials Medusa hands to its
storage driver. The exact contents depend on the backend; this is the format expected by `s3` and `s3_compatible`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: medusa-bucket-key
  namespace: k8ssandra
type: Opaque
stringData:
  credentials: |
    [default]
    aws_access_key_id = <YOUR_ACCESS_KEY>
    aws_secret_access_key = <YOUR_SECRET_KEY>
```

For other backends (`google_storage`, `azure_blobs`, etc.), see the
[Medusa storage configuration docs](https://docs.k8ssandra.io/components/medusa/).

### Create a K8ssandraCluster with the Docker Hardened Medusa image

Set `spec.medusa.containerImage` to the DHI Medusa image. The K8ssandra `containerImage` schema treats `repository` as
the namespace inside the registry and `name` as the image name; for the DHI public image the namespace is empty, so only
`registry`, `name`, and `tag` are needed. The example below uses an S3-compatible bucket (e.g. MinIO); substitute
`storageProvider`, `host`, and `port` for your real backend.

```yaml
apiVersion: k8ssandra.io/v1alpha1
kind: K8ssandraCluster
metadata:
  name: demo
  namespace: k8ssandra
spec:
  cassandra:
    serverVersion: "4.0.17"
    datacenters:
      - metadata:
          name: dc1
        size: 3
    storageConfig:
      cassandraDataVolumeClaimSpec:
        storageClassName: standard
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 10Gi
  medusa:
    containerImage:
      registry: dhi.io
      name: k8ssandra-medusa
      tag: <tag>
    storageProperties:
      storageProvider: s3_compatible
      storageSecretRef:
        name: medusa-bucket-key
      bucketName: cassandra-backups
      prefix: demo
      host: minio.k8ssandra.svc.cluster.local
      port: 9000
      secure: false
    serviceProperties:
      grpcPort: 50051
```

If you mirror the image to your own registry under a namespace
(`<your-registry>/<your-namespace>/dhi-k8ssandra-medusa:<tag>`), set all four fields:

```yaml
medusa:
  containerImage:
    registry: <your-registry>
    repository: <your-namespace>
    name: dhi-k8ssandra-medusa
    tag: <tag>
```

Apply the manifest:

```bash
$ kubectl apply -f k8ssandracluster.yaml
```

The operator creates a Cassandra `StatefulSet` whose pods include a `medusa` sidecar container running this image and a
`medusa-restore` init container. You can confirm the sidecar is in place with:

```bash
$ kubectl -n k8ssandra get pod demo-dc1-default-sts-0 \
    -o jsonpath='{.spec.containers[*].name}'
cassandra medusa server-system-logger
```

### Override the default Medusa image at the chart level

The `k8ssandra-operator` Helm chart also lets you set a cluster-wide default Medusa image under
`global.imageConfig.images.medusa`, which applies to every `K8ssandraCluster` that doesn't override
`spec.medusa.containerImage`:

```yaml
global:
  imageConfig:
    images:
      medusa:
        registry: dhi.io
        name: k8ssandra-medusa
        tag: <tag>
```

The Medusa image is selected per `K8ssandraCluster` or via this chart-wide default; setting the chart's top-level
`image.registry` / `image.repository` only affects the operator container itself, **not** the Medusa sidecar.

## Trigger a backup with MedusaBackupJob

Once Medusa is enabled on a cluster, request a backup by creating a `MedusaBackupJob`. The operator will fan out the
backup across all nodes in the target `CassandraDatacenter`.

```yaml
apiVersion: medusa.k8ssandra.io/v1alpha1
kind: MedusaBackupJob
metadata:
  name: backup-1
  namespace: k8ssandra
spec:
  cassandraDatacenter: dc1
  backupType: differential
```

Apply and watch the job:

```bash
$ kubectl apply -f medusabackupjob.yaml
$ kubectl -n k8ssandra get medusabackupjob backup-1 -w
```

The backup is complete when `status.finishTime` is set; any per-node failures show up in `status.failed`.

For scheduled backups, point-in-time restores, and the full set of fields, see the upstream
[Medusa backup and restore guide](https://docs.k8ssandra.io/tasks/backup-restore/).

## Common K8ssandra Medusa use cases

For end-to-end examples and feature-specific manifests, refer to the upstream K8ssandra documentation:

- [Backup and restore overview](https://docs.k8ssandra.io/tasks/backup-restore/)
- [Medusa component reference](https://docs.k8ssandra.io/components/medusa/)
- [`MedusaBackupSchedule` reference](https://docs.k8ssandra.io/reference/crd/k8ssandra-operator-crds-latest/#medusabackupschedule)
- [`MedusaRestoreJob` reference](https://docs.k8ssandra.io/reference/crd/k8ssandra-operator-crds-latest/#medusarestorejob)

Use the image override patterns in this guide when you want to substitute the upstream Medusa image with the Docker
Hardened Image.

## What's intentionally omitted compared to upstream

The DHI variant of `k8ssandra-medusa` is a drop-in replacement for the upstream `k8ssandra/medusa` image for the
operator-driven backup/restore flow, but it intentionally omits a few things that ship in the upstream Dockerfile:

- **`gcloud` CLI / Google Cloud SDK.** Upstream installs the full Google Cloud SDK at `/usr/local/gcloud`. Medusa's GCS
  storage backend uses the `google-cloud-storage` Python library that ships in the bundled venv, so backups and restores
  against GCS work identically without the CLI. If you need ad-hoc `gcloud` access for debugging, run it in a separate
  container (for example, the `dhi/google-cloud-cli` image via `kubectl debug` or as a one-off `kubectl run`) rather
  than expecting it inside the Medusa sidecar.
- **`aws` CLI.** Upstream apt-installs `awscli`. Medusa's S3 and S3-compatible backends use `boto3` from the bundled
  venv, so backups and restores work without the CLI. Use a separate container for ad-hoc `aws s3` debugging.
- **Debian/Ubuntu build chain (`debhelper`, `dh-virtualenv`, `devscripts`, `equivs`, `build-essential`,
  `software-properties-common`, `gnupg`).** These are upstream build-time tools that were never required at runtime;
  they are kept out of the runtime image to reduce surface area. The `0-dev` and `0-fips-dev` variants include a package
  manager and a shell if you need a writable build environment.

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
  cryptographic operations.

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

For Medusa specifically, you can also inspect the running sidecar with:

```bash
$ kubectl -n k8ssandra logs <cassandra-pod> -c medusa
$ kubectl -n k8ssandra logs <cassandra-pod> -c medusa-restore   # init container
```

### Permissions

The Medusa sidecar runs as the `cassandra` user (UID 999) so it can share the Cassandra data volume with the Cassandra
container. If you mount a `Secret` or `ConfigMap` into the sidecar, make sure its `defaultMode` allows reads by UID 999.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The Medusa gRPC
server listens on `50051` by default, which is well above the privileged range.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. The Medusa entry
point is `/home/cassandra/docker-entrypoint.sh`, the same path as the upstream image. Use `docker inspect` to confirm if
you override it.

## FIPS

A FIPS-compliant variant of this image is available with the `-fips` suffix (e.g., `k8ssandra-medusa:0-fips`).

The FIPS variant is built with a FIPS-enabled Go toolchain (used by the bundled `grpc_health_probe` binary) and pins
strict FIPS mode at runtime via the following environment variables:

```
GODEBUG=fips140=only
GOFIPS140=v1.0.0
```

`GODEBUG=fips140=only` enforces strict FIPS 140-3 mode for any Go binary in the image; `GOFIPS140=v1.0.0` pins the Go
FIPS module version. Only `grpc_health_probe` is a Go binary in this image, and it makes plaintext localhost gRPC calls
so it never exercises non-FIPS algorithms at runtime. The Medusa Python sidecar handles its own TLS to S3-compatible
storage via the system OpenSSL FIPS provider, which is included in the FIPS variant.

Use the FIPS variant when deploying in environments that require FIPS 140-2 compliance, such as US federal government
workloads or FedRAMP-authorized systems.
