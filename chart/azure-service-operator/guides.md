## Installing the chart

### Prerequisites

- Kubernetes 1.16+
- Cert Manager

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
helm install my-azure-service-operator oci://dhi.io/azure-service-operator-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

With pre-requisites satisfied, Azure Service Operator should be ready to be used:

```console
kubectl get all
NAME                                                           READY   STATUS    RESTARTS      AGE
pod/azureserviceoperator-controller-manager-7bf986498-fb2q9   1/1     Running   0          11s
pod/azureserviceoperator-controller-manager-7bf986498-smbpw   1/1     Running   0          11s
pod/my-cert-manager-778c66ffc4-s26kj                          1/1     Running   0          96m
pod/my-cert-manager-cainjector-7dff7c8645-srcb8               1/1     Running   0          96m
pod/my-cert-manager-webhook-7f57dc8cc4-6rgdm                  1/1     Running   0          96m

NAME                                                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)            AGE
service/azureserviceoperator-controller-manager-metrics-service   ClusterIP   10.96.186.39   <none>        8443/TCP           11s
service/azureserviceoperator-webhook-service                      ClusterIP   10.96.156.51   <none>        443/TCP            11s
service/kubernetes                                                ClusterIP   10.96.0.1      <none>        443/TCP            7d10h
service/my-cert-manager                                           ClusterIP   10.96.49.244   <none>        9402/TCP           96m
service/my-cert-manager-cainjector                                ClusterIP   10.96.94.98    <none>        9402/TCP           96m
service/my-cert-manager-webhook                                   ClusterIP   10.96.231.6    <none>        443/TCP,9402/TCP   96m

NAME                                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/azureserviceoperator-controller-manager   2/2     2            2           11s
deployment.apps/my-cert-manager                           1/1     1            1           96m
deployment.apps/my-cert-manager-cainjector                1/1     1            1           96m
deployment.apps/my-cert-manager-webhook                   1/1     1            1           96m

NAME                                                                DESIRED   CURRENT   READY   AGE
replicaset.apps/azureserviceoperator-controller-manager-7bf986498   2         2         2       11s
replicaset.apps/my-cert-manager-778c66ffc4                          1         1         1       96m
replicaset.apps/my-cert-manager-cainjector-7dff7c8645               1         1         1       96m
replicaset.apps/my-cert-manager-webhook-7f57dc8cc4                  1         1         1       96m
```
