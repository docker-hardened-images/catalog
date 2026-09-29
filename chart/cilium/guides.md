## Installing the chart

### Prerequisites

- Kubernetes 1.21+ (recommended 1.30+)
- Helm 3.0+ (recommended 3.7+)

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

#### Step 3: Install the Helm chart

To install the chart, use `helm install`. Make sure you use `helm login` to log in before running `helm install`.
Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

Cilium must be installed in the `kube-system` namespace:

```console
helm install cilium oci://dhi.io/cilium-chart --version <version> \
  --namespace kube-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

After installing, verify that the Cilium agent pods are running on each node:

```bash
$ kubectl get pods -n kube-system -l k8s-app=cilium
NAME           READY   STATUS    RESTARTS   AGE
cilium-5b5vt   1/1     Running   0          2m
cilium-fxzqs   1/1     Running   0          2m
cilium-n7z9s   1/1     Running   0          2m
```

You can also use the Cilium CLI to verify the status of the installation:

```bash
cilium status --wait
```

### Enabling Hubble observability

Hubble is Cilium's built-in observability platform. To enable it during installation:

```console
helm install cilium oci://dhi.io/cilium-chart --version <version> \
  --namespace kube-system \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
```
