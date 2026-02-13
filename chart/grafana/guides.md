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

```console
helm install my-grafana oci://dhi.io/grafana-chart --version <version> \
  --set "global.imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```bash
$ kubectl get all

NAMESPACE     NAME                                           READY   STATUS    RESTARTS   AGE
default       pod/my-grafana-grafana-chart-6779fc7c6b-77k8c  1/1     Running   0          76s

NAMESPACE     NAME                               TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                  AGE
default       service/kubernetes                 ClusterIP   10.43.0.1     <none>        443/TCP                  113s
default       service/my-grafana-grafana-chart   ClusterIP   10.43.209.5   <none>        80/TCP                   76s

NAMESPACE     NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
default       deployment.apps/my-grafana-grafana-chart  1/1     1            1           76s

NAMESPACE     NAME                                                 DESIRED   CURRENT   READY   AGE
default       replicaset.apps/my-grafana-grafana-chart-6779fc7c6b  1         1         1       76s
```

To further validate, get the admin password, extract the pod, instruct the user to port forward and then the user can
validate that they can log in.

```bash
$ kubectl get secret --namespace default my-grafana-grafana-chart -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

gv3Fh4qDHrmDkkjnsJsDDMkHh30sqMu09QJ42iil

$ export POD_NAME=$(kubectl get pods --namespace default -1 "app.kubernetes.io/name=grafana-chart,app.kubernetes.
io/instance=my-grafana" -o jsonpath="{.items[0].metadata.name}")

$ kubectl--namespace default port-forward $POD_NAME 3000

Forwarding from 127.0.0.1:3000 - 3000
Forwarding from [::1]:3000 ->3000
Handling connection for 3000
Handling connection for 3000
```
