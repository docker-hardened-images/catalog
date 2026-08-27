## Installing the chart

### Prerequisites

- Kubernetes 1.25+ (recommended 1.30+)
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

```console
helm install my-kyverno oci://dhi.io/kyverno-chart --version <version> \
  --set "global.imagePullSecrets[0].name=helm-pull-secret"
```

To install the chart with reports-server, you need to provide connection information to an external PostgreSQL database,
as the the PostgreSQL subchart is not supported.

```console
helm install my-kyverno oci://dhi.io/kyverno-chart --version <version> \
  --set "global.imagePullSecrets[0].name=helm-pull-secret"
  --set "reportsServer.enabled=true" \
  --set "reports-server.imagePullSecrets[0].name=helm-pull-secret" \
  --set "reports-server.config.db.host=<postgres host>" \
  --set "reports-server.config.db.password=<postgres password>"
```

Note: As you might have noticed, upstream sets image pull secret slightly different to most charts.

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pods should show up and running almost immediately:

```bash
$ kubectl get all
NAME                                                       READY   STATUS    RESTARTS   AGE
pod/my-kyverno-admission-controller-759d4c858-55pt9     1/1     Running   0          24s
pod/my-kyverno-background-controller-6c45bcdc7d-xxgvx   1/1     Running   0          24s
pod/my-kyverno-cleanup-controller-7569df7845-g9fs2      1/1     Running   0          24s
pod/my-kyverno-reports-controller-9b747bb58-xkbxx       1/1     Running   0          24s

NAME                                                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/my-kyverno-background-controller-metrics    ClusterIP   10.43.85.187    <none>        8000/TCP   24s
service/my-kyverno-cleanup-controller               ClusterIP   10.43.112.6     <none>        443/TCP    24s
service/my-kyverno-cleanup-controller-metrics       ClusterIP   10.43.140.63    <none>        8000/TCP   24s
service/my-kyverno-reports-controller-metrics       ClusterIP   10.43.15.168    <none>        8000/TCP   24s
service/my-kyverno-chart-svc                        ClusterIP   10.43.103.56    <none>        443/TCP    24s
service/my-kyverno-chart-svc-metrics                ClusterIP   10.43.175.125   <none>        8000/TCP   24s

NAME                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/my-kyverno-admission-controller    1/1     1            1           24s
deployment.apps/my-kyverno-background-controller   1/1     1            1           24s
deployment.apps/my-kyverno-cleanup-controller      1/1     1            1           24s
deployment.apps/my-kyverno-reports-controller      1/1     1            1           24s

NAME                                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/my-kyverno-admission-controller-759d4c858     1         1         1       24s
replicaset.apps/my-kyverno-background-controller-6c45bcdc7d   1         1         1       24s
replicaset.apps/my-kyverno-cleanup-controller-7569df7845      1         1         1       24s
replicaset.apps/my-kyverno-reports-controller-9b747bb58       1         1         1       24s
```
