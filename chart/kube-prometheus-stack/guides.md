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
NAME                                                       READY   STATUS              RESTARTS   AGE
pod/prometheus-grafana-69fd8b9d4b-t6rgr                    3/3     Running             0          121m
pod/prometheus-kube-prometheus-operator-7fd9b9b879-j6hbc   1/1     Running             0          121m
pod/prometheus-kube-state-metrics-7657cf96db-qpl44         1/1     Running             0          121m
pod/prometheus-prometheus-node-exporter-7v9zh              1/1     Running             0          121m

NAME                                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/kubernetes                                ClusterIP   10.100.0.1       <none>        443/TCP             19d
service/prometheus-grafana                        ClusterIP   10.100.241.194   <none>        80/TCP              121m
service/prometheus-kube-prometheus-alertmanager   ClusterIP   10.100.41.108    <none>        9093/TCP,8080/TCP   121m
service/prometheus-kube-prometheus-operator       ClusterIP   10.100.183.149   <none>        443/TCP             121m
service/prometheus-kube-prometheus-prometheus     ClusterIP   10.100.174.85    <none>        9090/TCP,8080/TCP   121m
service/prometheus-kube-state-metrics             ClusterIP   10.100.105.240   <none>        8080/TCP            121m
service/prometheus-prometheus-node-exporter       ClusterIP   10.100.151.155   <none>        9100/TCP            121m

NAME                                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/prometheus-prometheus-node-exporter   2         2         2       2            2           kubernetes.io/os=linux   121m

NAME                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/prometheus-grafana                    1/1     1            1           121m
deployment.apps/prometheus-kube-prometheus-operator   1/1     1            1           121m
deployment.apps/prometheus-kube-state-metrics         1/1     1            1           121m

NAME                                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/prometheus-grafana-69fd8b9d4b                    1         1         1       121m
replicaset.apps/prometheus-kube-prometheus-operator-7fd9b9b879   1         1         1       121m
replicaset.apps/prometheus-kube-state-metrics-7657cf96db         1         1         1       121m
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
