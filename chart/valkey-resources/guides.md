## Installing the chart

### Prerequisites

- Kubernetes 1.31+

- Helm 3.5+

- The [valkey-operator](https://github.com/valkey-io/valkey-helm/tree/main/valkey-operator) (v0.4.0+) installed and
  running in the cluster. This chart only creates a `ValkeyCluster` custom resource; it does not install the operator or
  the `ValkeyCluster` custom resource definition (CRD) the operator registers. Without the operator, the Kubernetes API
  server rejects the `ValkeyCluster` resource this chart creates.

### Installation steps

All examples in this guide use the public chart. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored chart instead of the public one.

For example:

- Public chart: `dhi.io/<repository>:<tag>`
- Mirrored chart: `<your-namespace>/dhi-<repository>:<tag>`

For more details about customizing the chart, see the [documentation](https://docs.docker.com/dhi/how-to/customize/).

#### Step 1: Optional. Mirror the Helm chart to your own registry

To optionally mirror the chart to your own third-party registry, you can follow the instructions in
[How to mirror an image](https://docs.docker.com/dhi/how-to/mirror/).

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

This chart renders only a `ValkeyCluster` custom resource (and, optionally, a `PodMonitor`) and does not reference any
container images, so no image pull secret is needed to install it.

#### Step 2: Install the Helm chart

To install the chart, use `helm install`. Make sure you use `docker login dhi.io` to authenticate before pulling the
chart. Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

```console
docker login dhi.io
helm install my-valkey-resources oci://dhi.io/valkey-resources-chart --version <version> -n valkey --create-namespace
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace.

#### Step 3: Verify the installation

```console
$ kubectl get valkeyclusters -n valkey
NAME                             STATE   REASON   READYSHARDS   AGE
my-valkey-resources-chart        Ready            3             30s

$ kubectl get valkeynodes -n valkey
```

## Common use cases

### Set the shard and replica topology

Override the number of shard groups and the number of replicas per shard:

```console
helm install my-valkey-resources oci://dhi.io/valkey-resources-chart --version <version> -n valkey --create-namespace \
  --set cluster.spec.shards=5 \
  --set cluster.spec.replicas=2
```

### Enable Prometheus metrics scraping

Create a `PodMonitor` for the operator's per-node `metrics-exporter` sidecars, selected by the Prometheus Operator using
a `release` label:

```console
helm install my-valkey-resources oci://dhi.io/valkey-resources-chart --version <version> -n valkey --create-namespace \
  --set metrics.podMonitor.enabled=true \
  --set "metrics.podMonitor.labels.release=prometheus"
```

For custom `cluster.spec` fields (persistence, scheduling, TLS, etc.), see the
[ValkeyCluster API documentation](https://github.com/valkey-io/valkey-operator/blob/main/docs/valkeycluster.md).
