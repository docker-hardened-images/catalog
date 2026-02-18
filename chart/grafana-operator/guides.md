## Installing the chart

### Prerequisites

- Kubernetes 1.21+ (recommended 1.30+)
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
helm install grafana-operator oci://dhi.io/grafana-operator-chart --version <version> \
  --set "pullSecrets[0]=helm-pull-secret" \
```

Note: As you might have noticed, upstream sets image pull secret slightly different to most charts.

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pods should show up and running almost immediately:

```bash
$ kubectl get all
NAME                                                           READY   STATUS    RESTARTS   AGE
pod/grafana-operator-grafana-operator-chart-565f658666-77qr5   1/1     Running   0          4s

NAME                                                              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
service/grafana-operator-grafana-operator-chart-metrics-service   ClusterIP   10.109.89.195   <none>        9090/TCP,8888/TCP   4s
service/kubernetes                                                ClusterIP   10.96.0.1       <none>        443/TCP             5d22h

NAME                                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/grafana-operator-grafana-operator-chart   1/1     1            1           4s

NAME                                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/grafana-operator-grafana-operator-chart-565f658666   1         1         1       4s
```

Then you should be able to verify the installation by installing a new Grafana instance.

WARNING: Please DO NOT CREATE AN INSTANCE LIKE THIS IN PRODUCTION. The example below has a hardcoded admin password.
This is just included for the sake of quick manual verification of the operator Helm chart.

```bash
cat > grafana.yaml << EOF
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: grafana
  labels:
    dashboards: "grafana"
spec:
  config:
    log:
      mode: "console"
    auth:
      disable_login_form: "false"
    security:
      admin_user: root
      admin_password: secret
EOF
```

Also, note that the above instructs the operator to create a default Grafana instance. By default, the operator will use
the upstream Grafana image. If you want to use Docker's Hardened Grafana image instead, you can point the manifest to
your Grafana DHI like this (replace tag and pull secret as needed):

```bash
cat > grafana.yaml << EOF
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: grafana
  labels:
    dashboards: "grafana"
spec:
  version: dhi.io/grafana:<tag>
  config:
    log:
      mode: "console"
    auth:
      disable_login_form: "false"
    security:
      admin_user: root
      admin_password: secret
  deployment:
    spec:
      template:
        spec:
          imagePullSecrets:
            - name: helm-pull-secret
EOF
```

Apply the manifest to create the Grafana instance:

```bash
kubectl apply -f grafana.yaml
```

And you will see a new Grafana instance up after a few seconds:

```bash
kubectl get all
NAME                                                           READY   STATUS    RESTARTS   AGE
pod/grafana-deployment-bfd5c8999-2n8tp                         1/1     Running   0          18s
pod/grafana-operator-grafana-operator-chart-565f658666-77qr5   1/1     Running   0          30s

NAME                                                              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
service/grafana-alerting                                          ClusterIP   None            <none>        9094/TCP            18s
service/grafana-operator-grafana-operator-chart-metrics-service   ClusterIP   10.109.89.195   <none>        9090/TCP,8888/TCP   30s
service/grafana-service                                           ClusterIP   10.106.179.68   <none>        3000/TCP            18s
service/kubernetes                                                ClusterIP   10.96.0.1       <none>        443/TCP             5d22h

NAME                                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/grafana-deployment                        1/1     1            1           18s
deployment.apps/grafana-operator-grafana-operator-chart   1/1     1            1           30s

NAME                                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/grafana-deployment-bfd5c8999                         1         1         1       18s
replicaset.apps/grafana-operator-grafana-operator-chart-565f658666   1         1         1       30s
```

That has started a Grafana instance. You can also instruct the operator to create a Grafana Dashboard:

```bash
cat > dashboard.yaml << EOF
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: grafanadashboard-sample
spec:
  resyncPeriod: 30s
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  json: >
    {
      "id": null,
      "title": "Simple Dashboard",
      "tags": [],
      "style": "dark",
      "timezone": "browser",
      "editable": true,
      "hideControls": false,
      "graphTooltip": 1,
      "panels": [],
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {
        "time_options": [],
        "refresh_intervals": []
      },
      "templating": {
        "list": []
      },
      "annotations": {
        "list": []
      },
      "refresh": "5s",
      "schemaVersion": 17,
      "version": 0,
      "links": []
    }
EOF
```

Apply and check that exists:

```console
kubectl apply -f dashboard.yaml
grafanadashboard.grafana.integreatly.org/grafanadashboard-sample created

kubectl get GrafanaDashboard
NAME                      NO MATCHING INSTANCES   LAST RESYNC   AGE
grafanadashboard-sample                           6s            6s
```

Finally, if you open a port forward rule to the grafana service.

```bash
kubectl port-forward svc/grafana-service 3000:3000
```

That should open port 3000 on your localhost and via your web browser you will be able to access the Grafana instance
with the dummy credentials from the example above. Then on the left menu, if you navigate to the Dashboards section you
will find our sample dashboard too.
