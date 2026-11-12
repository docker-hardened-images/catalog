## How to use this image

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
- Has no entrypoint and defaults to `/bin/bash`, so an explicit command such as `ceph --version` runs directly
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
override the Ceph image to use the Docker Hardened Image. Select a Ceph tag ending in `-compat` for Rook. Rook's OSD
containers run as UID 0, and its monitor, manager, and exporter bootstrap containers must change ownership on Ceph data
directories. The compat flavor matches that upstream runtime contract without adding the package manager from the dev
variant. Regular runtime tags remain nonroot and are intended for direct CLI use or custom deployments that provide
their own bootstrap security contexts.

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

In this command, `<tag>` must be the complete compat tag, for example `20.3.0-debian13-compat`.

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
deprecated top-level `storage.directories` field. Use a complete `-compat` tag for `<tag>`.

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

| Feature         | Upstream `quay.io/ceph/ceph:v20.2.2` | Docker Hardened `dhi.io/ceph:<tag>`                                     |
| --------------- | ------------------------------------ | ----------------------------------------------------------------------- |
| User            | Runs as root by default              | Runtime tags use UID 167; Rook compat tags explicitly use UID 0         |
| Entrypoint      | None                                 | None                                                                    |
| Default command | `/bin/bash`                          | `/bin/bash`; an explicit Ceph command replaces it directly              |
| Shell access    | Includes `/bin/bash`                 | Includes `/bin/sh` and `/bin/bash` in the current Debian runtime        |
| Package manager | Includes `dnf`                       | No package manager in runtime or compat tags                            |
| Python runtime  | System Python layout                 | Hardened `/usr/bin/python3` with Ceph modules under `/usr/local/lib`    |
| Intended usage  | General-purpose image for Rook       | Nonroot CLI runtime plus an explicit root compatibility flavor for Rook |

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
  - Are the right choice for direct CLI invocations and custom nonroot deployments

- Compat tags:

  - Run as UID 0 to match the upstream Ceph image contract required by Rook's bootstrap and OSD containers
  - Contain the same runtime payload and still omit the package manager
  - Are the supported choice for Rook-managed clusters

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

| Item               | Migration note                                                                                                                                                |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Image reference    | For Rook, replace `quay.io/ceph/ceph:v20.3.0` with a complete compat tag such as `dhi.io/ceph:20.3.0-debian13-compat`. Use a regular runtime tag for CLI use. |
| Default command    | Both images have no entrypoint and default to `/bin/bash`, so an explicit command such as `ceph --version` or `rados` executes directly.                      |
| Default user       | Regular runtime tags use `ceph` (UID 167). Rook compat tags explicitly use UID 0 because upstream Rook requires root for OSD and bootstrap operations.        |
| Package management | Use `-dev` variants when you need `apt` or package-install workflows. Runtime and compat tags intentionally omit a package manager.                           |
| Runtime shell      | The current Debian runtime image includes `/bin/sh` and `/bin/bash`, but direct use should still pass an explicit Ceph command.                               |
| TLS certificates   | Standard CA certificates are already present; you do not need to add them just to talk to TLS-enabled Ceph endpoints.                                         |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile or deployment manifest.

   Use a compat tag for Rook, a regular runtime tag for nonroot CLI use, and a `-dev` tag only when you need
   package-manager access for build or debug workflows.

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

Regular runtime tags run as UID 167. Ensure mounted files and directories are accessible to that user. Do not use a
regular runtime tag as a drop-in Rook image: Rook's OSD and bootstrap operations require the explicit root compat
flavor.

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
