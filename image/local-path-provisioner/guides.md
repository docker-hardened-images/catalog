## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About this image

This Docker Hardened Local Path Provisioner image contains the `local-path-provisioner` binary from the
[Rancher Local Path Provisioner](https://github.com/rancher/local-path-provisioner) project.

Local Path Provisioner enables dynamic provisioning of Kubernetes persistent volumes backed by local node storage. It
watches for `PersistentVolumeClaim` objects and automatically creates either `hostPath` or `local` persistent volumes on
the scheduled node. Storage paths are configurable per node using a Kubernetes ConfigMap, and the provisioner
automatically cleans up volumes when the associated PVC is deleted. It is the default storage provider in K3s and other
lightweight Kubernetes distributions.

### Run the local-path-provisioner container

Local Path Provisioner is designed to run inside a Kubernetes cluster. It requires access to the Kubernetes API and a
properly configured service account.

To display version information:

```bash
docker run --rm dhi.io/local-path-provisioner:<tag> --version
```

To display help information:

```bash
docker run --rm dhi.io/local-path-provisioner:<tag> --help
```

### Deploy Local Path Provisioner in Kubernetes

The recommended deployment method is to apply the upstream manifest and replace the image reference with the Docker
Hardened image.

1. Download the manifest for your target release:

```bash
curl -LO https://raw.githubusercontent.com/rancher/local-path-provisioner/v<VERSION>/deploy/local-path-storage.yaml
```

2. Replace the upstream image reference with the Docker Hardened image:

```bash
sed -i 's|rancher/local-path-provisioner:v<VERSION>|dhi.io/local-path-provisioner:<tag>|g' local-path-storage.yaml
```

3. Apply the manifest:

```bash
kubectl apply -f local-path-storage.yaml
```

4. Verify the provisioner is running:

```bash
kubectl -n local-path-storage get pod
```

You should see output similar to:

```
NAME                                     READY   STATUS    RESTARTS   AGE
local-path-provisioner-d744ccf98-xfcbk   1/1     Running   0          30s
```

> **Note:** The dev variants of this image run as root. If the deployment manifest includes `runAsNonRoot: true` in the
> pod security context, dev variants will not start. Modify the security context to set `runAsNonRoot: false` if you
> need to deploy a dev variant.

### Configure storage paths

Local Path Provisioner reads its configuration from a ConfigMap named `local-path-config` in the `local-path-storage`
namespace. The default configuration stores volumes under `/opt/local-path-provisioner` on every node. You can customize
this per node using the `nodePathMap` field.

Example ConfigMap with per-node path customization:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["/opt/local-path-provisioner"]
        },
        {
          "node": "node1",
          "paths": ["/data/local-path"]
        },
        {
          "node": "node2",
          "paths": []
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    mkdir -m 0777 -p "$VOL_DIR"
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "$VOL_DIR"
  helperPod.yaml: |-
    apiVersion: v1
    kind: Pod
    metadata:
      name: helper-pod
    spec:
      priorityClassName: system-node-critical
      tolerations:
        - key: node.kubernetes.io/disk-pressure
          operator: Exists
          effect: NoSchedule
      containers:
      - name: helper-pod
        image: busybox
        imagePullPolicy: IfNotPresent
```

Notes on the ConfigMap:

- Nodes listed with an empty `paths` array (`[]`) will be excluded from provisioning.
- If a node is not listed, the `DEFAULT_PATH_FOR_NON_LISTED_NODES` paths are used.
- When multiple paths are specified for a node, the provisioner chooses one randomly.
- Configuration changes are reloaded automatically without restarting the provisioner.

### Use a custom StorageClass

By default, the provisioner registers the `local-path` StorageClass. You can define additional StorageClasses that pin
provisioning to a specific node path or use a custom volume naming pattern:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ssd-local-path
provisioner: rancher.io/local-path
parameters:
  nodePath: /data/ssd
  pathPattern: "{{ .PVC.Namespace }}/{{ .PVC.Name }}/"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

To select `hostPath` or `local` volume type, add an annotation to the PVC:

```yaml
annotations:
  volumeType: local
```

If neither annotation is present, the provisioner defaults to `hostPath`.

### Provision a PersistentVolume

After the provisioner is deployed, create a PVC using the `local-path` StorageClass:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-path-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 2Gi
```

Apply the PVC and verify it is bound:

```bash
kubectl apply -f pvc.yaml
kubectl get pvc local-path-pvc
```

A PersistentVolume is created automatically on the node where the workload is scheduled (with
`volumeBindingMode: WaitForFirstConsumer`) or immediately (with `volumeBindingMode: Immediate`).

### Monitor the provisioner

Follow the provisioner logs to observe volume provisioning and teardown events:

```bash
kubectl -n local-path-storage logs -f -l app=local-path-provisioner
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
