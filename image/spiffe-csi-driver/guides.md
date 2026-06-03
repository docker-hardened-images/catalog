## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/spiffe-csi-driver:<tag>`
- Mirrored image: `<your-namespace>/dhi-spiffe-csi-driver:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Run the spiffe-csi-driver container

The SPIFFE CSI Driver is designed to run within a Kubernetes cluster as part of a SPIRE agent DaemonSet. It communicates
with the kubelet over Unix domain sockets and requires privileged execution; running it standalone outside of Kubernetes
is not a supported use case.

To confirm the binary is present in the image and view the available flags, replace `<tag>` with the image variant you
want to inspect:

```bash
$ docker run --rm dhi.io/spiffe-csi-driver:<tag> --help
```

## Deploy SPIFFE CSI Driver in Kubernetes

The SPIFFE CSI Driver must be deployed in Kubernetes, where it registers as a CSI plugin with the kubelet. The
recommended way to deploy the full SPIRE stack — including the SPIFFE CSI Driver — is using the official
[SPIFFE Helm Charts (hardened)](https://github.com/spiffe/helm-charts-hardened).

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

### Deploy with the SPIFFE Helm Charts

The `spiffe-csi-driver` image is bundled within the SPIRE chart in the
[helm-charts-hardened](https://github.com/spiffe/helm-charts-hardened) repository. Override the CSI driver image to use
Docker Hardened Images via a `values.yaml` file.

Create a `values.yaml` file and configure the SPIFFE CSI Driver to use your Docker Hardened Image. Replace `<tag>` with
the image variant you want to use.

```yaml
spiffe-csi-driver:
  image:
    registry: dhi.io
    repository: spiffe-csi-driver
    tag: <tag>
```

Install the SPIRE CRDs and stack with your custom values:

```console
$ helm upgrade --install -n spire spire-crds spire-crds \
    --repo https://spiffe.github.io/helm-charts-hardened/

$ helm upgrade --install -n spire spire spire \
    --repo https://spiffe.github.io/helm-charts-hardened/ -f values.yaml
```

Verify the SPIFFE CSI Driver DaemonSet is running:

```console
$ kubectl get daemonset -n spire -l app.kubernetes.io/name=spiffe-csi-driver
```

Verify the deployment is using the DHI image:

```console
$ kubectl -n spire get pods -l app.kubernetes.io/name=spiffe-csi-driver \
    -o jsonpath='{.items[*].spec.containers[0].image}'
```

### Deploy with a standalone DaemonSet manifest

If you are not using Helm, you can deploy the SPIFFE CSI Driver manually. The following manifest registers the CSIDriver
resource and deploys the driver alongside the CSI Node Driver Registrar sidecar. Update the image references to point to
your Docker Hardened Images. Replace `<tag>` with a `spiffe-csi-driver` variant tag and `<registrar-tag>` with a
compatible `csi-node-driver-registrar` tag (for example `0.2` and `2`); the sidecar uses a different version line than
the driver.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spiffe-csi-driver
  namespace: spire
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: spiffe-csi-driver
  namespace: spire
  labels:
    app: spiffe-csi-driver
spec:
  selector:
    matchLabels:
      app: spiffe-csi-driver
  template:
    metadata:
      labels:
        app: spiffe-csi-driver
    spec:
      serviceAccountName: spiffe-csi-driver
      containers:
        - name: spiffe-csi-driver
          image: dhi.io/spiffe-csi-driver:<tag>
          imagePullPolicy: IfNotPresent
          args:
            - "-workload-api-socket-dir"
            - "/spire-agent-socket"
            - "-csi-socket-path"
            - "/spiffe-csi/csi.sock"
          env:
            - name: MY_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          volumeMounts:
            - mountPath: /spire-agent-socket
              name: spire-agent-socket-dir
              readOnly: true
            - mountPath: /spiffe-csi
              name: spiffe-csi-socket-dir
            - mountPath: /var/lib/kubelet/pods
              mountPropagation: Bidirectional
              name: mountpoint-dir
          securityContext:
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
            privileged: true
        - name: node-driver-registrar
          image: dhi.io/csi-node-driver-registrar:<registrar-tag>
          imagePullPolicy: IfNotPresent
          args:
            - "-csi-address"
            - "/spiffe-csi/csi.sock"
            - "-kubelet-registration-path"
            - "/var/lib/kubelet/plugins/csi.spiffe.io/csi.sock"
          volumeMounts:
            - mountPath: /spiffe-csi
              name: spiffe-csi-socket-dir
            - name: kubelet-plugin-registration-dir
              mountPath: /registration
      volumes:
        - name: spire-agent-socket-dir
          hostPath:
            path: /run/spire/agent-sockets
            type: DirectoryOrCreate
        - name: spiffe-csi-socket-dir
          hostPath:
            path: /var/lib/kubelet/plugins/csi.spiffe.io
            type: DirectoryOrCreate
        - name: mountpoint-dir
          hostPath:
            path: /var/lib/kubelet/pods
            type: Directory
        - name: kubelet-plugin-registration-dir
          hostPath:
            path: /var/lib/kubelet/plugins_registry
            type: Directory
---
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: "csi.spiffe.io"
spec:
  attachRequired: false
  podInfoOnMount: true
  fsGroupPolicy: None
  volumeLifecycleModes:
    - Ephemeral
```

Apply the manifest:

```console
$ kubectl apply -f spiffe-csi-driver.yaml
```

### Use the SPIFFE CSI Driver in a workload pod

Once the driver is registered, workload pods can request the SPIFFE Workload API socket by declaring an ephemeral inline
volume:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-workload
spec:
  containers:
    - name: my-app
      image: my-app:latest
      volumeMounts:
        - name: spiffe-workload-api
          mountPath: /run/spiffe/sockets
          readOnly: true
  volumes:
    - name: spiffe-workload-api
      csi:
        driver: csi.spiffe.io
        readOnly: true
```

### Verify the CSI Driver registration

Confirm the CSI driver is registered with the Kubernetes API server:

```console
$ kubectl get csidriver csi.spiffe.io
```

Check the SPIFFE CSI Driver logs for mount activity:

```console
$ kubectl logs -n spire -l app=spiffe-csi-driver -c spiffe-csi-driver
```

> **Note:** The SPIFFE CSI Driver must run as `privileged: true` in its security context because it performs bind mounts
> into other pods' namespaces. The `dhi.io/spiffe-csi-driver` image runs as nonroot (UID 65532) by default, but
> Kubernetes will apply the `privileged` security context defined in the pod spec. Ensure your cluster policy allows
> privileged DaemonSet containers in the namespace where the driver is deployed.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

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
