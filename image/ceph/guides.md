## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use, update the commands
to reference your mirrored image instead of the public one.

For example:

- Public image: `dhi.io/ceph:<tag>`
- Mirrored image: `<your-namespace>/dhi-ceph:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Ceph image

This Docker Hardened Ceph image is intended primarily for Rook-managed Kubernetes deployments. It includes the Ceph
runtime components and CLI tools commonly needed by Ceph daemon pods and cluster administrators:

- `ceph` for cluster administration and status checks
- `rados` for low-level RADOS operations
- `rbd` for block device operations
- `radosgw-admin` for RGW administration
- `python3` plus the `rados` Python binding used by Ceph's Python-based components

The runtime image:

- Runs as the `ceph` user by default
- Has no entrypoint and defaults to `/bin/bash`; for Ceph workloads, direct `docker run` usage should still specify a
  binary
- Includes `/bin/sh` for minimal scripting
- Does not include a package manager in the runtime image

## Start a Ceph container

> **Note:** This image is not a single-container Ceph appliance. It is designed to be consumed by Rook or invoked
> directly for Ceph CLI and utility commands.

Run the following command and replace `<tag>` with the image tag you want to use:

```bash
docker run --rm dhi.io/ceph:<tag> ceph --version
```

Display the `rados` help output:

```bash
docker run --rm dhi.io/ceph:<tag> rados --help
```

Verify that the Python bindings are present:

```bash
docker run --rm dhi.io/ceph:<tag> \
  python3 -c 'import rados; print(rados.__file__)'
```

## Common Ceph use cases

### Deploy Ceph with the Rook Helm charts

Rook separates the operator chart from the cluster chart. Install the operator first, then install the Ceph cluster and
override the Ceph image to use the Docker Hardened Image.

```bash
helm repo add rook-release https://charts.rook.io/release
helm repo update

helm install --create-namespace --namespace rook-ceph \
  rook-ceph rook-release/rook-ceph

helm install --create-namespace --namespace rook-ceph \
  rook-ceph-cluster rook-release/rook-ceph-cluster \
  --set operatorNamespace=rook-ceph \
  --set cephImage.repository=dhi.io/ceph \
  --set cephImage.tag=<tag>
```

### Use a CephCluster manifest with an explicit DHI image

If you manage Rook resources directly instead of through Helm, set `spec.cephVersion.image` to the hardened Ceph image:

```yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: dhi.io/ceph:<tag>
  mon:
    count: 3
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: worker-1
        devices:
          - name: /dev/sdb
```

This example intentionally uses the current `storage.nodes[].devices[]` schema. Avoid older examples that use the
deprecated top-level `storage.directories` field.

### Run the Ceph CLI against an existing cluster

Mount your Ceph configuration and keyring files into the container and invoke the CLI directly:

```bash
docker run --rm -it \
  -v "$PWD/ceph.conf:/etc/ceph/ceph.conf:ro" \
  -v "$PWD/ceph.client.admin.keyring:/etc/ceph/ceph.client.admin.keyring:ro" \
  dhi.io/ceph:<tag> \
  ceph -s
```

### Validate the Python bindings in automation

If you run Ceph automation or health checks that rely on the Python bindings, you can verify the runtime layout with:

```bash
docker run --rm dhi.io/ceph:<tag> \
  python3 -c 'import rados,sys; print(sys.executable); print(rados.__file__)'
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Upstream `quay.io/ceph/ceph:v20.2.0` | Docker Hardened `dhi.io/ceph:<tag>`                                  |
| --------------- | ------------------------------------ | -------------------------------------------------------------------- |
| User            | Runs as root by default              | Runs as `ceph` by default (UID 167)                                  |
| Default command | Starts with `/bin/bash` by default   | Also defaults to `/bin/bash`; explicit Ceph commands are recommended |
| Shell access    | Includes `/bin/bash`                 | Includes `/bin/sh` and `/bin/bash` in current runtime                |
| Package manager | Includes `dnf`                       | No package manager in the runtime image                              |
| Python runtime  | System Python layout                 | Hardened Python at `/opt/python` plus runtime wrappers               |
| Intended usage  | General-purpose upstream image       | Rook-focused runtime image plus explicit CLI invocations             |

### Hardened image debugging

The Ceph runtime image includes a shell in the current Debian variant, but Docker Debug is still the preferred way to
inspect the filesystem and compare behavior because it gives you a richer toolset without changing the image contents.

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools

For example, you can use Docker Debug:

```
docker debug dhi.io/ceph:<tag>
```

### Image variants

Ceph publishes runtime-oriented and development-oriented variants in this repository.

- Runtime tags:

  - Run as the `ceph` user
  - Include the Ceph daemons, CLI tools, Python runtime, and `rados` binding
  - Do not include a package manager
  - Are the right choice for Rook-managed clusters and direct CLI invocations

- Dev tags:

  - Run as `root`
  - Include `bash`, `apt`, and locale data
  - Are intended for build stages, troubleshooting, and package-install workflows

- FIPS tags:

  - Include the OpenSSL FIPS provider used for the image's light-FIPS posture
  - Preserve the same Rook-focused runtime model as the non-FIPS runtime image
  - Should be selected explicitly rather than assumed from a non-FIPS tag name

## Migrate to a Docker Hardened Image

If you are migrating from the upstream Ceph container to this image, focus on the behavior differences that matter for
automation and cluster deployment.

| Item               | Migration note                                                                                                                                             |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image reference    | Replace upstream references such as `quay.io/ceph/ceph:v20.3.0` with the hardened image tag you want to run, for example `dhi.io/ceph:20.3.0-debian13`.    |
| Default command    | Both images default to `/bin/bash`, but automation should still pass an explicit command such as `ceph --version` or `rados`.                              |
| Default user       | The hardened runtime image runs as `ceph` (UID 167) instead of root. Ensure mounted files and directories are readable or writable by that user as needed. |
| Package management | Use `-dev` variants when you need `apt` or other package-install workflows. The runtime image intentionally omits a package manager.                       |
| Runtime shell      | The current Debian runtime image includes `/bin/sh` and `/bin/bash`, but it is still intended for explicit commands and Rook-managed operation.            |
| TLS certificates   | Standard CA certificates are already present; you do not need to add them just to talk to TLS-enabled Ceph endpoints.                                      |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile or deployment manifest.

   Use a runtime tag for running Ceph daemons or CLI commands, and use a `-dev` tag only when you need package-manager
   access or an explicitly root-oriented build/debug environment.

1. Install additional packages only in `-dev` workflows.

   If your workflow needs Debian package installation, use a `dhi.io/ceph:<tag>-dev` image for that stage. Keep the
   final runtime image on a non-dev tag.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

Even though the current Debian runtime image includes a shell,
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) is still the preferred inspection tool because it
avoids relying on image-internal utilities and matches how other minimal DHI runtime images are commonly debugged.

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

### Runtime shell vs dev shell

The current Debian runtime image already includes `/bin/sh` and `/bin/bash`, but `-dev` tags remain the right choice
when you need root, `apt`, locale tooling, or other build/debug conveniences that are intentionally absent from the
runtime image.

### Entry point

The hardened runtime image does not declare an entrypoint, and its default command is `/bin/bash`. That generally
matches the upstream image, but for Ceph workloads you should still invoke an explicit binary such as `ceph`, `rados`,
or `python3` when running the container directly.
