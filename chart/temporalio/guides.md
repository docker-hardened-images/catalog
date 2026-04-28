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

#### Step 3: Install the Helm chart

To install the chart, use `helm install`. Make sure you use `helm login` to log in before running `helm install`.
Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

Temporal requires setting up a database in order to startup correctly. The upstream chart provides sample values to
update the default values.yaml with for many common configurations at
https://github.com/temporalio/helm-charts/tree/main/charts/temporal/values. Update any sepcific values for the chosen
database and install using those custom values. For example, to install with a postgres database:

1. Fetch the applicable example values file and update the values according to your postgres deployment.

```bash
wget https://raw.githubusercontent.com/temporalio/helm-charts/temporal-<chart version>/charts/temporal/values/values.postgresql.yaml
```

2. Install the helm chart with those updated values.

```console
helm install my-temporal oci://dhi.io/temporalio-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  -f postgresql.values.yaml
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

To install with Elasticsearch as the visibility datastore instead:

1. Fetch the Elasticsearch example values file and update the values according to your Elasticsearch deployment.

```bash
wget https://raw.githubusercontent.com/temporalio/helm-charts/temporal-<chart version>/charts/temporal/values/values.elasticsearch.yaml
```

2. Install the helm chart with those updated values.

```console
helm install my-temporal oci://dhi.io/temporalio-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  -f values.elasticsearch.yaml
```

Replace `<version>`, `dhi.io`, and `helm-pull-secret` as described above.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```bash
$ kubectl get all
NAMESPACE     NAME                                                  READY   STATUS     RESTARTS   AGE
default       pod/my-temporalio-chart-admintools-6b7bd89444-zzbr9   1/1     Running    0          35s
default       pod/my-temporalio-chart-frontend-7486f65c9b-8dmsp     1/1     Running    0          35s
default       pod/my-temporalio-chart-history-7b765c8488-z4xq9      1/1     Running    0          35s
default       pod/my-temporalio-chart-matching-64c6f96957-5hkn2     1/1     Running    0          35s
default       pod/my-temporalio-chart-worker-65554487cb-2dcq2       1/1     Running    0          35s

NAMESPACE     NAME                                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
default       service/kubernetes                              ClusterIP   10.43.0.1       <none>        443/TCP                      113s
default       service/my-temporalio-chart-frontend            ClusterIP   10.43.79.115    <none>        7233/TCP,7243/TCP            35s
default       service/my-temporalio-chart-frontend-headless   ClusterIP   None            <none>        7233/TCP,6933/TCP,9090/TCP   35s
default       service/my-temporalio-chart-history-headless    ClusterIP   None            <none>        7234/TCP,6934/TCP,9090/TCP   35s
default       service/my-temporalio-chart-internal-frontend   ClusterIP   10.43.113.255   <none>        7236/TCP,7246/TCP            35s
default       service/my-temporalio-chart-matching-headless   ClusterIP   None            <none>        7235/TCP,6935/TCP,9090/TCP   35s
default       service/my-temporalio-chart-web                 ClusterIP   10.43.98.160    <none>        8080/TCP                     35s
default       service/my-temporalio-chart-worker-headless     ClusterIP   None            <none>        7239/TCP,6939/TCP,9090/TCP   35s

NAMESPACE     NAME                                             READY   UP-TO-DATE   AVAILABLE   AGE
default       deployment.apps/my-temporalio-chart-admintools   1/1     1            1           35s
default       deployment.apps/my-temporalio-chart-frontend     1/1     1            1           35s
default       deployment.apps/my-temporalio-chart-history      1/1     1            1           35s
default       deployment.apps/my-temporalio-chart-matching     1/1     1            1           35s
default       deployment.apps/my-temporalio-chart-worker       1/1     1            1           35s

NAMESPACE     NAME                                                        DESIRED   CURRENT   READY   AGE
default       replicaset.apps/my-temporalio-chart-admintools-6b7bd89444   1         1         1       35s
default       replicaset.apps/my-temporalio-chart-frontend-7486f65c9b     1         1         1       35s
default       replicaset.apps/my-temporalio-chart-history-7b765c8488      1         1         1       35s
default       replicaset.apps/my-temporalio-chart-matching-64c6f96957     1         1         1       35s
default       replicaset.apps/my-temporalio-chart-worker-65554487cb       1         1         1       35s
```

To further validate, port forward port 8080 from the web pod and then the user can validate that they can access the
webui at localhost:8080.

```bash
$ export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/component=web,app.kubernetes.io/instance=temporal" -o jsonpath="{.items[0].metadata.name}")

$ kubectl --namespace default port-forward $POD_NAME 8080

Forwarding from 127.0.0.1:8080 - 8080
Forwarding from [::1]:8080 ->8080
Handling connection for 8080
Handling connection for 8080
```
