## Installing the chart

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

#### Step 3: Configure storage

Grafana Tempo requires a storage backend for trace data. For production use, configure an S3-compatible object store.
For development or evaluation, local filesystem storage can be used.

**Production (S3):**

```yaml
# tempo-values.yaml
tempo:
  storage:
    trace:
      backend: s3
      s3:
        bucket: my-tempo-traces
        endpoint: s3.amazonaws.com
        region: us-east-1
        access_key: <access-key>
        secret_key: <secret-key>
```

**Development (local filesystem):**

```yaml
# tempo-values.yaml
tempo:
  storage:
    trace:
      backend: local
      local:
        path: /var/tempo/traces
```

#### Step 4: Install the Helm chart

```console
helm install my-tempo oci://dhi.io/tempo-chart --version <version> \
  --set "tempo.pullSecrets[0]=helm-pull-secret" \
  --set "tempoQuery.pullSecrets[0]=helm-pull-secret" \
  -f tempo-values.yaml
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 5: Verify the installation

The deployment's pod should show up and running shortly:

```bash
$ kubectl get all

NAME                             READY   STATUS    RESTARTS   AGE
pod/my-tempo-tempo-chart-0       1/1     Running   0          30s

NAME                             TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
service/my-tempo-tempo-chart     ClusterIP   10.96.0.1     <none>        3200/TCP   30s

NAME                                        READY   AGE
statefulset.apps/my-tempo-tempo-chart       1/1     30s
```

Verify Tempo is healthy:

```bash
export POD_NAME=$(kubectl get pods -l "app.kubernetes.io/instance=my-tempo" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 3200 &
curl http://localhost:3200/ready
```

#### Step 6: Send traces to Tempo

Configure your OpenTelemetry Collector or application SDK to send traces to Tempo using OTLP:

```yaml
# OpenTelemetry Collector exporter configuration
exporters:
  otlp:
    endpoint: my-tempo-tempo-chart.<namespace>.svc.cluster.local:4317
    tls:
      insecure: true
```

#### Step 7: Query traces in Grafana

Add Tempo as a data source in Grafana:

1. Go to **Configuration > Data Sources > Add data source**
1. Select **Tempo**
1. Set the URL to `http://my-tempo-tempo-chart.<namespace>.svc.cluster.local:3200`
1. Click **Save & Test**

You can then explore traces in **Explore** using TraceQL:

```traceql
{ .service.name = "my-service" }
```
