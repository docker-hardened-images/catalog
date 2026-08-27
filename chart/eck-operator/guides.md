## Installing the chart

### Prerequisites

- Kubernetes 1.21+
- Helm 3.0+

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
helm install my-eck-operator oci://dhi.io/eck-operator-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

If the chart is in your own registry or repository, replace `dhi.io` with your own registry and namespace. Replace
`helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

Check that the ECK operator is running:

```console
kubectl get statefulset -n default
kubectl get pods -n default -l app.kubernetes.io/name=elastic-operator
```

You should see the operator pod in a Running state.

#### Step 5: Deploy Elastic Stack resources

After the operator is installed, you can deploy Elasticsearch, Kibana, and other Elastic Stack resources. The operator
will manage these resources automatically.

For example, to deploy an Elasticsearch cluster:

```yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 9.2.6
  image: dhi.io/elasticsearch:9.3
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
```

Apply the manifest:

```console
kubectl apply -f elasticsearch.yaml
```

For more information on deploying Elastic Stack resources with ECK, see the
[official ECK documentation](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s).
