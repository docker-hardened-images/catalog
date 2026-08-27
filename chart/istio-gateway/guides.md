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

Install the chart with a release name and namespace. The `dhi.io/istio-base-chart` and `dhi.io/istio-discovery-chart`
must be installed before this chart. The `istio-discovery` chart (istiod) acts as a mutating webhook that automatically
injects the `dhi/istio-proxyv2` image into the gateway pod at deploy time — without it, the gateway will not start.

Make sure you use `helm login` to log in before running `helm install`. Optionally, you can also use the `--dry-run`
flag to test the installation without actually installing anything.

```console
helm install istio-gateway oci://dhi.io/istio-gateway-chart --version <version> \
  -n istio-system --create-namespace \
  --set "global.imagePullSecrets[0]=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or namespace, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created in Step 2.

For more options and values, see the [Istio installation documentation](https://istio.io/latest/docs/setup/install/).

#### Step 4: Verify the installation

The gateway deployment and pods should show up and be running in the `istio-gateway` namespace:

```bash
$ kubectl get all -n istio-system
NAME                          READY   STATUS    RESTARTS   AGE
pod/istiod-664d45ddb6-f2qdn   1/1     Running   0          3m44s
pod/istio-gateway-6d556564b5-wtzcz     1/1     Running   0          3m38s

NAME             TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                      AGE
service/istiod   ClusterIP      10.43.229.78    <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP        3m44s
service/istio-gateway     LoadBalancer   10.43.223.179   172.17.0.5    15021:30329/TCP,80:31904/TCP,443:31011/TCP   3m38s

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istiod   1/1     1            1           3m44s
deployment.apps/istio-gateway     1/1     1            1           3m38s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/istiod-664d45ddb6   1         1         1       3m44s
replicaset.apps/istio-gateway-6d556564b5     1         1         1       3m38s

NAME                                         REFERENCE           TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/istiod   Deployment/istiod   cpu: <unknown>/80%   1         5         1          3m44s
horizontalpodautoscaler.autoscaling/istio-gateway     Deployment/istio-gateway     cpu: <unknown>/80%   1         5         1          3m38s
```

### Uninstall

```console
helm uninstall istio-gateway -n istio-gateway
```
