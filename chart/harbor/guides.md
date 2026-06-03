## Installing the chart

### Prerequisites

- Kubernetes 1.20+ (recommended 1.26+)
- Helm 3.8+
- A default StorageClass or pre-provisioned PersistentVolumes (Harbor requires persistent storage for the registry,
  database, Redis, and Trivy cache)

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

Harbor requires several mandatory configuration values before installation. At a minimum you must supply an external URL
and an admin password:

```console
helm install my-harbor oci://dhi.io/harbor-chart --version <version> \
  --set "expose.type=ingress" \
  --set "expose.ingress.hosts.core=harbor.example.com" \
  --set "externalURL=https://harbor.example.com" \
  --set "harborAdminPassword=<your-secure-password>" \
  --set "secretKey=<16-character-secret-key>" \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The Harbor pods should start within a few minutes. Verify all components are running:

```bash
$ kubectl get all -n default
NAME                                          READY   STATUS    RESTARTS   AGE
pod/my-harbor-core-7d8b9c4f6-xk2pq           1/1     Running   0          2m
pod/my-harbor-database-0                      1/1     Running   0          2m
pod/my-harbor-exporter-6f9c8b7d5-ml2qt       1/1     Running   0          2m
pod/my-harbor-jobservice-5e7d6c4b3-np3rs      1/1     Running   0          2m
pod/my-harbor-portal-4c5e6d3b2-qr4tv          1/1     Running   0          2m
pod/my-harbor-redis-0                         1/1     Running   0          2m
pod/my-harbor-registry-6b7c8d9e5-uv5wx        1/1     Running   0          2m
pod/my-harbor-trivy-0                         1/1     Running   0          2m

NAME                              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/my-harbor-core            ClusterIP   10.43.101.42    <none>        80/TCP     2m
service/my-harbor-database        ClusterIP   10.43.102.43    <none>        5432/TCP   2m
service/my-harbor-jobservice      ClusterIP   10.43.103.44    <none>        80/TCP     2m
service/my-harbor-portal          ClusterIP   10.43.104.45    <none>        80/TCP     2m
service/my-harbor-redis           ClusterIP   10.43.105.46    <none>        6379/TCP   2m
service/my-harbor-registry        ClusterIP   10.43.106.47    <none>        5000/TCP   2m
service/my-harbor-trivy           ClusterIP   10.43.107.48    <none>        8080/TCP   2m
```

Once all pods are running, access the Harbor portal via your configured `externalURL`. Log in with username `admin` and
the password you set via `harborAdminPassword`.
