## Installing the chart

### Prerequisites

- Kubernetes 1.21+ (recommended 1.30+)
- Helm 3.6+ (recommended 3.7+)

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
[How to mirror an image ](https://docs.docker.com/dhi/how-to/mirror/) for either the chart, the image, or both.

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

This Helm chart expects the `istio-system` namespace to exist. So creating it is a prerequisite.

```console
kubectl create namespace istio-system
helm install istio-base oci://dhi.io/istio-base-chart --version <version>
```

#### Step 4: Verify the installation

This Helm chart provides base CRDs to other Istio Helm charts. You can validate that the CRDs have been creating by
doing a query on the istio label.

```console
kubectl get CustomResourceDefinition -l release=istio
NAME                                       CREATED AT
authorizationpolicies.security.istio.io    2026-02-19T09:39:09Z
destinationrules.networking.istio.io       2026-02-19T09:39:09Z
envoyfilters.networking.istio.io           2026-02-19T09:39:09Z
gateways.networking.istio.io               2026-02-19T09:39:09Z
peerauthentications.security.istio.io      2026-02-19T09:39:09Z
proxyconfigs.networking.istio.io           2026-02-19T09:39:09Z
requestauthentications.security.istio.io   2026-02-19T09:39:09Z
serviceentries.networking.istio.io         2026-02-19T09:39:09Z
sidecars.networking.istio.io               2026-02-19T09:39:09Z
telemetries.telemetry.istio.io             2026-02-19T09:39:09Z
virtualservices.networking.istio.io        2026-02-19T09:39:09Z
wasmplugins.extensions.istio.io            2026-02-19T09:39:09Z
workloadentries.networking.istio.io        2026-02-19T09:39:09Z
workloadgroups.networking.istio.io         2026-02-19T09:39:09Z
```
