## Installing the chart

### Prerequisites

- Kubernetes 1.28+
- Helm 3.x
- A default StorageClass (for the hub database's persistent volume)

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
helm install my-jupyterhub oci://dhi.io/zero-to-jupyterhub-k8s-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The hub and proxy pods should show up and running almost immediately:

```console
$ kubectl get all
NAME                          READY   STATUS    RESTARTS   AGE
pod/hub-565d7b4cf-xwjzx       1/1     Running   0          11s
pod/proxy-77f4f6ff6d-fhfd8    1/1     Running   0          11s

NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/hub            ClusterIP      10.43.85.120    <none>        8081/TCP                     11s
service/proxy-api      ClusterIP      10.43.213.187   <none>        8001/TCP                     11s
service/proxy-http     ClusterIP      10.43.75.77     <none>        8000/TCP                     11s
service/proxy-public   LoadBalancer   10.43.101.220   172.17.0.6    443:30195/TCP,80:32738/TCP   11s

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hub      1/1     1            1           11s
deployment.apps/proxy    1/1     1            1           11s
```

Get the proxy's external address and open it in your browser to reach the JupyterHub login page:

```console
kubectl get service proxy-public
```
