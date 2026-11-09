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

#### Step 3: Configure object storage

Unlike the upstream chart, this chart doesn't deploy MinIO. Grafana Mimir needs an object storage backend for its
blocks, rules, and Alertmanager state, which you configure in `mimir.structuredConfig`. Create a `mimir-values.yaml`
file. The following example uses Amazon S3, replace the endpoint, region, and bucket names with your own:

```yaml
mimir:
  structuredConfig:
    common:
      storage:
        backend: s3
        s3:
          endpoint: s3.us-east-1.amazonaws.com
          region: us-east-1
    blocks_storage:
      s3:
        bucket_name: <blocks bucket>
    alertmanager_storage:
      s3:
        bucket_name: <alertmanager bucket>
    ruler_storage:
      s3:
        bucket_name: <ruler bucket>
```

For other backends such as Google Cloud Storage or Azure Blob Storage, see the
[Grafana Mimir object storage documentation](https://grafana.com/docs/mimir/latest/configure/configure-object-storage-backend/).

#### Step 4: Install the Helm chart

To install the chart, use `helm install`. Make sure you use `helm login` to log in before running `helm install`.
Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

```console
helm install my-mimir oci://dhi.io/mimir-distributed-chart --version <version> \
  --values mimir-values.yaml \
  --set "image.pullSecrets[0]=helm-pull-secret" \
  --set "kafka.image.pullSecrets[0]=helm-pull-secret" \
  --set "rollout_operator.imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 5: Verify the installation

The Grafana Mimir components, the gateway, and Kafka should start and become ready:

```console
kubectl get pods
```

To check that the gateway answers, forward its port and send a request:

```console
kubectl port-forward svc/my-mimir-gateway 8080:80
curl http://localhost:8080/
```

The gateway answers `OK`. Grafana Mimir is multi-tenant, so queries need a tenant ID in the `X-Scope-OrgID` header:

```console
curl -H "X-Scope-OrgID: demo" "http://localhost:8080/prometheus/api/v1/labels"
```
