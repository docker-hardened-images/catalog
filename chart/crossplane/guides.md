## Installing the chart

### Prerequisites

- Kubernetes 1.32+ (Any
  [actively supported version](https://docs.crossplane.io/v2.2/get-started/install/#prerequisites))
- Helm 3.2+

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

**Note**: The chart's default `imagePullSecrets` value matches upstream (an empty array `[]`). You need to override it
with your pull secret name.

```console
helm install my-crossplane oci://dhi.io/crossplane-chart --version <version> \
  --namespace crossplane-system \
  --create-namespace \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

If the chart is in your own registry or repository, replace `dhi.io` with your own registry and namespace. Replace
`helm-pull-secret` with the name of the image pull secret you created earlier.

**Optional: Install a Provider during installation**

You can optionally install one or more Providers at the same time as Crossplane by setting the `provider.packages`
value:

```console
helm install my-crossplane oci://dhi.io/crossplane-chart --version <version> \
  --namespace crossplane-system \
  --create-namespace \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  --set "provider.packages={xpkg.crossplane.io/crossplane-contrib/provider-aws-s3:<version>}"
```

For multiple providers, use a comma-separated list:

```console
helm install my-crossplane oci://dhi.io/crossplane-chart --version <version> \
  --namespace crossplane-system \
  --create-namespace \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  --set "provider.packages={xpkg.crossplane.io/crossplane-contrib/provider-aws-s3:<version>,xpkg.upbound.io/upbound/provider-gcp:<version2>}"
```

#### Step 4: Verify the installation

After installation, verify that Crossplane is running:

```console
kubectl get pods -n crossplane-system
```

You should see the Crossplane and RBAC Manager pods running:

```console
NAME                                      READY   STATUS    RESTARTS   AGE
crossplane-xxxxxxxxxx-xxxxx               1/1     Running   0          1m
crossplane-rbac-manager-xxxxxxxxxx-xxxxx  1/1     Running   0          1m
```

#### Step 5: Next steps for functioning

After installing Crossplane, you need to install Providers to enable infrastructure provisioning. Providers extend
Crossplane to manage resources on external services like AWS, Azure, GCP, and more.

**Install a Provider:**

Crossplane uses Provider packages to add support for different cloud providers. You can install providers using the
Crossplane CLI or by creating Provider resources.

For example, to install the AWS provider:

```console
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: xpkg.upbound.io/upbound/provider-aws:v0.40.0
EOF
```

**Verify the Provider installation:**

```console
kubectl get providers
```

**Configure Provider credentials:**

After installing a provider, you need to configure it with credentials to access your cloud provider. Refer to the
[Crossplane documentation](https://docs.crossplane.io/latest/getting-started/provider-aws/) for detailed instructions on
configuring providers.

**Next steps:**

- Install additional Providers for other cloud platforms
- Create Compositions to define infrastructure templates
- Define Composite Resources (XRs) for your platform APIs
- Explore the [Crossplane documentation](https://docs.crossplane.io/) for advanced usage

For more information on getting started with Crossplane, visit the official documentation at
https://docs.crossplane.io/latest/getting-started/.
