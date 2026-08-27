## Installing the chart

### Prerequisites

- Helm 3.6+
- Kubernetes cluster with Istio control plane already installed (`istio-base` and `istio-discovery`)

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

#### Step 3: Install the chart

Install the chart with a release name and namespace. The egress gateway is typically installed in a dedicated namespace
(e.g. `istio-egress`). Make sure `istio-discovery` is already running before installing this chart, as the egress
gateway requires the Istio control plane to be available.

Make sure you use `helm login` to log in before running `helm install`. Optionally, you can also use the `--dry-run`
flag to test the installation without actually installing anything.

```console
helm install istio-egress oci://dhi.io/istio-egress-chart --version <version> \
  -n istio-egress --create-namespace \
  --set "global.imagePullSecrets[0]=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or namespace, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created in Step 2.

For more options and values, see the [Istio installation documentation](https://istio.io/latest/docs/setup/install/).

#### Step 4: Verify the installation

The egress gateway deployment and pods should show up and be running in the `istio-egress` namespace:

```bash
$ kubectl get all -n istio-egress
NAME                                       READY   STATUS    RESTARTS   AGE
pod/istio-egressgateway-849748fd8f-brlwc   1/1     Running   0          42s

NAME                          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/istio-egressgateway   ClusterIP   10.43.25.239   <none>        80/TCP,443/TCP   42s

NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istio-egressgateway   1/1     1            1           42s

NAME                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/istio-egressgateway-849748fd8f   1         1         1       42s

NAME                                                      REFERENCE                        TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/istio-egressgateway   Deployment/istio-egressgateway   cpu: <unknown>/80%   1         5         1          42s
```

### Uninstall

```console
helm uninstall istio-egress -n istio-egress
```
