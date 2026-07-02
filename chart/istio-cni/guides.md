## Installing the chart

### Prerequisites

- Helm 3.6+
- Kubernetes cluster with `istio-base` already installed

### Installation steps

All examples in this guide use the public chart and images. If you've mirrored the repository for your own use (for
example, to your Docker Hub namespace), update your commands to reference the mirrored chart instead of the public one.

For example:

- Public chart: `dhi.io/<repository>:<tag>`
- Mirrored chart: `<your-namespace>/dhi-<repository>:<tag>`

For more details about customizing the chart to reference other images, see the
[documentation](https://docs.docker.com/dhi/how-to/customize/).

#### Step 1: Optional. Mirror the Helm chart and/or its images to your own registry

To optionally mirror a chart to your own third-party registry, you can follow the instructions in
[How to mirror an image](https://docs.docker.com/dhi/how-to/mirror/) for either the chart, the image, or both.

The same `regctl` tool that is used for mirroring container images can also be used for mirroring Helm charts, as Helm
charts are OCI artifacts.

For example:

```console
 regctl image copy \
     "${SRC_CHART_REPO}:${TAG}" \
     "${DEST_REG}/${DEST_CHART_REPO}:${TAG}" \
     --referrers \
     --referrers-src "${SRC_ATT_REPO}" \
     --referrers-tgt "${DEST_REG}/${DEST_CHART_REPO}" \
     --force-recursive
```

#### Step 2: Create a Kubernetes secret for pulling images

The Docker Hardened Images that the chart uses require authentication. To allow your Kubernetes cluster to pull those
images, you need to create a Kubernetes secret with your Docker Hub credentials or with the credentials for your own
registry.

Follow the [authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

For example:

```console
kubectl create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<Docker username> \
  --docker-password=<Docker token> \
  --docker-email=<Docker email>
```

#### Step 3: Install the chart

Install the chart with a release name and namespace. The CNI plugin is typically installed in the `istio-system`
namespace. Make sure `istio-base` is already installed before installing this chart. The CNI plugin should be installed
before or alongside `istio-discovery` so that the CNI configuration is in place when workload pods are scheduled.

Make sure you use `helm login` to log in before running `helm install`. Optionally, you can also use the `--dry-run`
flag to test the installation without actually installing anything.

```console
helm install istio-cni oci://dhi.io/istio-cni-chart --version <version> \
  -n istio-system --create-namespace \
  --set "global.imagePullSecrets[0]=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or namespace, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created in Step 2.

For more options and values, see the
[Istio CNI installation documentation](https://istio.io/latest/docs/setup/additional-setup/cni/).

#### Step 4: Verify the installation

The CNI plugin DaemonSet should be running on all nodes in the `istio-system` namespace:

```bash
$ kubectl get all -n istio-system -l k8s-app=istio-cni-node
NAME                        READY   STATUS    RESTARTS   AGE
pod/istio-cni-node-4xt7z    1/1     Running   0          30s
pod/istio-cni-node-7hkqp    1/1     Running   0          30s
pod/istio-cni-node-nwmgj    1/1     Running   0          30s

NAME                             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/istio-cni-node    3         3         3       3            3           kubernetes.io/os=linux   30s
```

### Uninstall

```console
helm uninstall istio-cni -n istio-system
```
