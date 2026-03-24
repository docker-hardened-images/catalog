## Installing the chart

### Installation steps

All examples in this guide use the public chart and images. If you've mirrored the repository for your own use (for
example, to your Docker Hub namespace), update your commands to reference the mirrored chart instead of the public one.

For example:

- Public chart: `oci://dhi.io/kube-prometheus-stack-chart`
- Mirrored chart: `oci://<your-registry>/<your-namespace>/kube-prometheus-stack-chart`

For more details about customizing the chart to reference other images, see the
[documentation](https://docs.docker.com/dhi/how-to/customize/).

#### Step 1: Optional. Mirror the Helm chart and/or its images to your own registry

To optionally mirror a chart to your own third-party registry, follow the instructions in
[How to mirror an image](https://docs.docker.com/dhi/how-to/mirror/) for either the chart, the image, or both. The same
`regctl` tool used for container images can mirror Helm charts as OCI artifacts.

#### Step 2: Create a Kubernetes secret for pulling images

The Docker Hardened Images that the chart uses require authentication. Create a Kubernetes secret with your Docker Hub
credentials or with the credentials for your own registry.

Follow the [authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

```console
kubectl create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<Docker username> \
  --docker-password=<Docker token> \
  --docker-email=<Docker email>
```

#### Step 3: Install the Helm chart

Use `helm install`. Run `helm login` before `helm install` if using the DHI registry.

```console
helm install my-kube-prometheus-stack oci://dhi.io/kube-prometheus-stack-chart --version <version> \
  --set "global.imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` with the chart version. Replace `dhi.io` and `helm-pull-secret` if using your own registry or
secret.

#### Step 4: Verify the installation

Check that the stack components are running:

```bash
kubectl get all
NAME                                                               READY   STATUS    RESTARTS   AGE
pod/alertmanager-my-kube-prometheus-stack-k-alertmanager-0         2/2     Running   0          3m11s
pod/my-kube-prometheus-stack-grafana-559cc98657-t6djg              3/3     Running   0          3m12s
pod/my-kube-prometheus-stack-k-operator-669f9b9cdf-rflrb           1/1     Running   0          3m12s
pod/my-kube-prometheus-stack-kube-state-metrics-66559fb987-qrmlt   1/1     Running   0          3m12s
pod/my-kube-prometheus-stack-prometheus-node-exporter-c2bzx        1/1     Running   0          3m12s
pod/my-kube-prometheus-stack-prometheus-node-exporter-mw279        1/1     Running   0          3m12s
pod/my-kube-prometheus-stack-prometheus-node-exporter-w84d2        1/1     Running   0          3m12s
pod/prometheus-my-kube-prometheus-stack-k-prometheus-0             2/2     Running   0          3m11s

NAME                                                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/alertmanager-operated                               ClusterIP   None            <none>        9093/TCP,9094/TCP,9094/UDP   3m11s
service/kubernetes                                          ClusterIP   10.43.0.1       <none>        443/TCP                      24h
service/my-kube-prometheus-stack-grafana                    ClusterIP   10.43.223.67    <none>        80/TCP                       3m12s
service/my-kube-prometheus-stack-k-alertmanager             ClusterIP   10.43.199.150   <none>        9093/TCP,8080/TCP            3m12s
service/my-kube-prometheus-stack-k-operator                 ClusterIP   10.43.171.158   <none>        443/TCP                      3m12s
service/my-kube-prometheus-stack-k-prometheus               ClusterIP   10.43.251.61    <none>        9090/TCP,8080/TCP            3m12s
service/my-kube-prometheus-stack-kube-state-metrics         ClusterIP   10.43.180.90    <none>        8080/TCP                     3m12s
service/my-kube-prometheus-stack-prometheus-node-exporter   ClusterIP   10.43.243.209   <none>        9100/TCP                     3m12s
service/prometheus-operated                                 ClusterIP   None            <none>        9090/TCP                     3m11s

NAME                                                               DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/my-kube-prometheus-stack-prometheus-node-exporter   3         3         3       3            3           kubernetes.io/os=linux   3m12s

NAME                                                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/my-kube-prometheus-stack-grafana              1/1     1            1           3m12s
deployment.apps/my-kube-prometheus-stack-k-operator           1/1     1            1           3m12s
deployment.apps/my-kube-prometheus-stack-kube-state-metrics   1/1     1            1           3m12s

NAME                                                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/my-kube-prometheus-stack-grafana-559cc98657              1         1         1       3m12s
replicaset.apps/my-kube-prometheus-stack-k-operator-669f9b9cdf           1         1         1       3m12s
replicaset.apps/my-kube-prometheus-stack-kube-state-metrics-66559fb987   1         1         1       3m12s

NAME                                                                    READY   AGE
statefulset.apps/alertmanager-my-kube-prometheus-stack-k-alertmanager   1/1     3m11s
statefulset.apps/prometheus-my-kube-prometheus-stack-k-prometheus       1/1     3m11s
```

To get the Grafana admin password, by default it will be in a secret suffixed with "-grafana"

```bash
kubectl get secret --namespace <namespace> my-kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Port-forward to access Grafana:

```bash
kubectl port-forward --namespace <namespace> svc/my-kube-prometheus-stack-grafana 3000:80
```

Then open http://localhost:3000 and log in with user `admin` and the password from above.
