## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Goldilocks Hardened image

This image contains the `goldilocks` an utility that can help you identify a starting point for resource requests and
limits.

## Prerequisites

Before deploying Goldilocks, ensure your cluster has the required components:

### 1. Install Vertical Pod Autoscaler

VPA must be installed in your cluster for Goldilocks to function. You can install VPA using the hack/vpa-up.sh script
from the vertical-pod-autoscaler repository

### 2. Install Metrics Server

VPA requires metrics to generate recommendations:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Common Goldilocks use cases

### Install Goldilocks using Helm

You can install Goldilocks using the official Helm chart and replace the image. Replace `<your-registry-secret>` with
your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>` with the desired image tag.

```bash
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update

helm install goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  --create-namespace \
  --set "imagePullSecrets[0].name=<your-registry-secret>" \
  --set image.repository=dhi.io/goldilocks \
  --set image.tag=<tag>
```

Verify the installation:

```console
kubectl get all -n goldilocks

kubectl get all
NAME                                         READY   STATUS        RESTARTS   AGE
pod/goldilocks-controller-6f46c7bb45-6djmf   1/1     Running       0          21s
pod/goldilocks-dashboard-86ccdb49c5-jlwbp    1/1     Running       0          21s
pod/goldilocks-dashboard-86ccdb49c5-t2q2b    1/1     Running       0          21s

NAME                           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/goldilocks-dashboard   ClusterIP   10.97.196.176   <none>        80/TCP    21s

NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/goldilocks-controller   1/1     1            1           21s
deployment.apps/goldilocks-dashboard    2/2     2            2           21s

NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/goldilocks-controller-6f46c7bb45   1         1         1       21s
replicaset.apps/goldilocks-dashboard-86ccdb49c5    2         2         2       21s
```

You should see both the controller and dashboard pods running.

### Enable Goldilocks for a namespace

Label a namespace to enable Goldilocks monitoring:

```bash
kubectl label namespace my-app goldilocks.fairwinds.com/enabled=true
```

The controller will automatically create VPA objects for all Deployments, StatefulSets, and DaemonSets in the namespace.

Verify VPA objects were created:

```bash
kubectl get vpa -n my-app
```

### Configure VPA update mode

Control how VPA applies recommendations using namespace labels:

```bash
# Off mode (default) - recommendations only, no automatic updates
kubectl label namespace my-app goldilocks.fairwinds.com/vpa-update-mode=off

# Auto mode - VPA automatically updates pod resources
kubectl label namespace my-app goldilocks.fairwinds.com/vpa-update-mode=auto

# Recreate mode - VPA recreates pods with new resources
kubectl label namespace my-app goldilocks.fairwinds.com/vpa-update-mode=recreate

# Initial mode - only set resources for new pods
kubectl label namespace my-app goldilocks.fairwinds.com/vpa-update-mode=initial
```

**Best practice**: Always start with `off` mode to review recommendations before applying them automatically.

### Access the dashboard

Port-forward the dashboard service to your local machine:

```bash
kubectl port-forward -n goldilocks svc/goldilocks-dashboard 8080:80
```

Then open http://localhost:8080 in your browser to view recommendations.

### Using Docker CLI

You can run Goldilocks commands directly with Docker for testing or local usage.

#### Check version

```bash
docker run --rm dhi.io/goldilocks:<tag> version
```

#### Run controller locally

```bash
docker run --rm \
  -v ~/.kube/config:/kubeconfig \
  dhi.io/goldilocks:<tag> \
  controller \
  --kubeconfig=/kubeconfig \
  -v2
```

#### Run dashboard locally

```bash
docker run --rm -p 8080:8080 \
  -v ~/.kube/config:/kubeconfig \
  dhi.io/goldilocks:<tag> \
  dashboard \
  --kubeconfig=/kubeconfig \
  --port=8080 \
  -v2
```

Then access the dashboard at http://localhost:8080

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

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

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
