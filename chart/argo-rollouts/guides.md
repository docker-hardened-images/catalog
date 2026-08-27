## Installing the chart

### Prerequisites

- Kubernetes 1.21+
- Helm 3.x

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
helm install argo-rollouts oci://dhi.io/argo-rollouts-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  --set "dashboard.enable=true"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pod should show up and running almost immediately:

```bash
$ kubectl get pods
NAME                                                    READY   STATUS    RESTARTS   AGE
pod/test-argo-rollouts-chart-5cd8b6c9bd-2k8v9           1/1     Running   0          53s
pod/test-argo-rollouts-chart-5cd8b6c9bd-rt424           1/1     Running   0          53s
pod/test-argo-rollouts-chart-dashboard-b959dddf-vjr5g   1/1     Running   0          53s

NAME                                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/kubernetes                           ClusterIP   10.43.0.1       <none>        443/TCP    71s
service/test-argo-rollouts-chart-dashboard   ClusterIP   10.43.202.210   <none>        3100/TCP   53s

NAME                                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/test-argo-rollouts-chart             2/2     2            2           53s
deployment.apps/test-argo-rollouts-chart-dashboard   1/1     1            1           53s

NAME                                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/test-argo-rollouts-chart-5cd8b6c9bd           2         2         2       53s
replicaset.apps/test-argo-rollouts-chart-dashboard-b959dddf   1         1         1       53s
```

Once all resources are healthy, you can open a port forward rule to the dashboard:

```console
k3sctl port-forward service/test-argo-rollouts-chart-dashboard  3100:3100
Forwarding from 127.0.0.1:3100 -> 3100
Forwarding from [::1]:3100 -> 3100
```

Navigate then to http://localhost:3100 to access the Argo Events dashboard.
