## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/multus-dynamic-networks-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-multus-dynamic-networks-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this multus-dynamic-networks-controller image

This Docker Hardened Image includes the following component:

- `multus-dynamic-networks-controller`: A Kubernetes controller that watches for changes to pod network annotations and
  dynamically attaches or detaches additional network interfaces on running pods

The controller works alongside [Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni) to enable hot-plugging
of network interfaces without requiring pod restarts.

## Deploy the Multus Dynamic Networks Controller

The Multus Dynamic Networks Controller is a Kubernetes controller and is not run directly with `docker run`. It is
deployed inside a Kubernetes cluster alongside [Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni),
typically using the upstream deployment manifests. The DHI image replaces the default upstream image in the deployment.

### Prerequisites

Before deploying the Multus Dynamic Networks Controller, ensure the following:

- A running Kubernetes cluster (v1.22 or later recommended)
- [Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni) is installed and configured in the cluster
- At least one additional CNI plugin is available (for example, macvlan, bridge, or SR-IOV)
- `NetworkAttachmentDefinition` CRDs are installed (these are provided by Multus CNI)

### Deploy with kubectl using the DHI image

1. Download the upstream deployment manifest:

```bash
curl -O https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-dynamic-networks-controller/main/manifests/dynamic-networks-controller.yaml
```

2. Update the image reference in the manifest to use the DHI image:

```bash
sed -i 's|ghcr.io/k8snetworkplumbingwg/multus-dynamic-networks-controller:.*|dhi.io/multus-dynamic-networks-controller:0|' dynamic-networks-controller.yaml
```

3. Apply the manifest:

```bash
kubectl apply -f dynamic-networks-controller.yaml
```

### Verify the deployment

```bash
kubectl get pods -n kube-system -l app=dynamic-networks-controller
```

Expected output:

```
NAME                                          READY   STATUS    RESTARTS   AGE
dynamic-networks-controller-<hash>            1/1     Running   0          60s
```

### Run the container

To display help information:

```bash
docker run --rm dhi.io/multus-dynamic-networks-controller:0 --help
```

## Common use cases

### Hot-plug an additional network interface to a running pod

Once the controller is running, you can dynamically attach a new network interface to a running pod by updating its
`k8s.v1.cni.cncf.io/networks` annotation.

1. First, ensure a `NetworkAttachmentDefinition` exists:

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf
spec:
  config: '{
    "cniVersion": "0.3.1",
    "type": "macvlan",
    "master": "eth0",
    "mode": "bridge",
    "ipam": {
      "type": "host-local",
      "subnet": "10.10.0.0/16"
    }
  }'
```

2. Annotate a running pod to attach the network:

```bash
kubectl annotate pod <pod-name> k8s.v1.cni.cncf.io/networks='macvlan-conf' --overwrite
```

3. Remove the annotation to detach the interface:

```bash
kubectl annotate pod <pod-name> k8s.v1.cni.cncf.io/networks='' --overwrite
```

## Using the -dev image variant

The `-dev` variant of the image (`dhi.io/multus-dynamic-networks-controller:0-dev`) includes a shell and common
utilities, making it useful for debugging and troubleshooting. The dev image runs as root and includes `bash`,
`ca-certificates`, `coreutils`, and `findutils`.

To inspect the controller binary or debug a running container, use Docker Debug with the runtime image:

```bash
docker debug <container-id>
```

To run the dev image locally and inspect its contents:

```bash
docker run --rm -it --entrypoint bash \
  dhi.io/multus-dynamic-networks-controller:0-dev
```

## Non-hardened images vs. Docker Hardened Images

| Feature         | Upstream (`ghcr.io/k8snetworkplumbingwg/multus-dynamic-networks-controller`) | Docker Hardened Image (`dhi.io/multus-dynamic-networks-controller`) |
| :-------------- | :--------------------------------------------------------------------------- | :------------------------------------------------------------------ |
| Base image      | Go builder / minimal base                                                    | Debian 13 (minimal, hardened)                                       |
| Run user        | Root                                                                         | `nonroot` (UID 65532)                                               |
| Shell           | May include shell utilities                                                  | No shell in runtime image                                           |
| CVE posture     | Standard upstream patching                                                   | Near-zero known CVEs, continuously patched                          |
| SBOM            | Not provided                                                                 | Full SBOM and VEX metadata included                                 |
| Provenance      | Not signed                                                                   | Signed provenance attestation                                       |
| Package manager | Not available at runtime                                                     | Not available at runtime (use `-dev` variant)                       |

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Available image tags for virt-controller:**

| Variant Type          | Tag Examples                             | Description                         |
| --------------------- | ---------------------------------------- | ----------------------------------- |
| **Standard (Debian)** | `<version>`, `<major>`                   | Runtime variants for production use |
|                       | `<version>-debian13`, `<major>-debian13` | Explicit Debian base specification  |

**Tag selection guidance:**

- Use `dhi.io/virt-controller:<version>` for standard production deployments
- Use major version tags (like `:<major>`) for automatic minor updates (not recommended for production)

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
validated under FIPS 140, a U.S. government standard for secure cryptographic operations.

**Runtime requirements specific to FIPS:**

- FIPS mode restricts cryptographic operations to FIPS-validated algorithms
- Usage of non-compliant operations (like MD5) will fail
- Larger image size due to FIPS-validated cryptographic libraries

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

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Debian-based images, you can use apt-get to install packages.

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
