## Installing the chart

### Prerequisites

- Kubernetes 1.20+
- Helm 3.2.0+

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

```console
helm install my-valkey-operator oci://dhi.io/valkey-operator-chart --version <version> \
  --create-namespace \
  -n valkey-operator-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```console
$ kubectl -n valkey-operator-system get pods -l app.kubernetes.io/instance=my-valkey-operator
NAME                                                       READY   STATUS    RESTARTS   AGE
my-valkey-operator-valkey-operator-chart-64dd674c49-bbtbz  1/1     Running   0          20s
```

With the operator now running, you can create your first Valkey cluster:

```console
cat > valkey-cluster.yaml << 'EOF'
apiVersion: valkey.io/v1alpha1
kind: ValkeyCluster
metadata:
  name: my-cluster
  namespace: default
spec:
  shards: 3
  replicas: 1
  image: dhi/valkey:9.1-debian13
  exporter:
    image: dhi/redis-exporter:1-debian13
  resources:
    requests:
      memory: "64Mi"
      cpu: "50m"
    limits:
      memory: "128Mi"
      cpu: "200m"
EOF
kubectl apply -f valkey-cluster.yaml
```

## Common valkey-operator use cases

### Restrict the operator to specific namespaces

By default the operator watches every namespace in the cluster. Restrict its informer cache to a set of namespaces with
the `manager.watchNamespaces` value, which maps to a repeated `--watch-namespace` flag on the operator binary:

```console
helm install my-valkey-operator oci://dhi.io/valkey-operator-chart --version <version> \
  --create-namespace \
  -n valkey-operator-system \
  --set manager.watchNamespaces[0]=valkey-prod \
  --set manager.watchNamespaces[1]=valkey-staging
```

### Operator with secure metrics endpoint

Enable secure metrics served over HTTPS with authn/authz:

```console
helm install my-valkey-operator oci://dhi.io/valkey-operator-chart --version <version> \
  --create-namespace \
  -n valkey-operator-system \
  --set metrics.secure=true
```

### Monitoring with Prometheus

Enable the built-in `ServiceMonitor` so the Prometheus Operator scrapes the operator's metrics endpoint:

```console
helm install my-valkey-operator oci://dhi.io/valkey-operator-chart --version <version> \
  --create-namespace \
  -n valkey-operator-system \
  --set metrics.serviceMonitor.enabled=true
```
