## How to use this image

All examples in this guide use the public images from the DHI catalog. If you've mirrored the repository for your own
use (for example, to your Docker Hub namespace), update your commands to reference the mirrored images instead of the
public ones.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For more details about customizing to reference other images, see the
[documentation](https://docs.docker.com/dhi/how-to/customize/).

### Prerequisites

- Kubernetes 1.20+
- Your Kubernetes cluster must either:
  - Run without a CNI plugin, or
  - Run a compatible CNI that can coexist with Calico
- A Kubernetes image pull secret for DHI authentication (see
  [authentication instructions](https://docs.docker.com/dhi/how-to/k8s/#authentication))

### Installation steps

#### Step 1: Install the Tigera Operator using the official Helm chart

The Tigera Operator is typically installed using the official Calico Helm chart. You can override the operator image to
use the Docker Hardened Image.

First, add the Calico Helm repository:

```console
helm repo add projectcalico https://docs.tigera.io/calico/charts
```

Then create a `values.yaml` file to customize the installation:

```yaml
tigeraOperator:
  registry: dhi.io
  image: tigera-operator
  # Due to a bug in the Helm chart, purely numeric tags (such as `"1.36"`) will fail even when properly quoted.
  # Use a tag that includes non-numeric characters, such as `1.36-debian13`.
  version: <tag>
installation:
  imagePullSecrets:
    - name: dhi-pull-secret
  # Optional: Specify your Kubernetes provider for optimized settings
  kubernetesProvider: ""  # Valid options: EKS, GKE, AKS, RKE2, OpenShift, DockerEnterprise, TKG
```

Replace `dhi-pull-secret` with the name of the image pull secret you created earlier.

Now install the operator. The version of the Helm chart should match the version of Calico you want to install. Check
the Calico version that the operator will install by running `docker run -it --rm dhi/tigera-operator:X.YY --version`.

```console
kubectl create namespace tigera-operator

helm install calico projectcalico/tigera-operator \
  --version vX.YY.Z \
  --namespace tigera-operator \
  -f values.yaml
```

#### Step 2: Verify the installation

The Tigera Operator will deploy resources in the `calico-system` namespace. Watch the pods to verify successful
deployment:

```console
watch kubectl get pods -n calico-system
```

All pods should reach the `Running` status:

```bash
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
calico-node-xxxxx                          1/1     Running   0          2m
calico-typha-xxxxxxxxxx-xxxxx              1/1     Running   0          2m
```

You can also verify the operator itself is running:

```console
kubectl get pods -n tigera-operator
```

To check the Installation custom resource status:

```console
kubectl get installation default -o yaml
```

Look for `status.conditions` to confirm the installation is progressing or complete.

## Image Variants

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

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
