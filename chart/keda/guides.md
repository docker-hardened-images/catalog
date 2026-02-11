## Installing the chart

### Prerequisites

- Kubernetes 1.23+ (recommended 1.30+)
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
helm install my-keda oci://dhi.io/keda-exporter-chart --version <version> \
  --set "pullSecrets[0]=helm-pull-secret.name" \
```

Note: As you might have noticed, upstream sets image pull secret slightly different to most charts.

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pods should show up and running almost immediately:

```bash
$ kubectl get all
NAME                                                  READY   STATUS    RESTARTS      AGE
pod/keda-admission-webhooks-6dccd9f565-lg497          1/1     Running   0             99s
pod/keda-operator-6bbd69f48b-nn2vd                    1/1     Running   0             99s
pod/keda-operator-metrics-apiserver-bfb497658-r68pz   1/1     Running   0             99s

NAME                                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)            AGE
service/keda-admission-webhooks           ClusterIP   10.43.242.3    <none>        443/TCP            99s
service/keda-operator                     ClusterIP   10.43.79.125   <none>        9666/TCP           99s
service/keda-operator-metrics-apiserver   ClusterIP   10.43.93.132   <none>        443/TCP,8080/TCP   99s
service/kubernetes                        ClusterIP   10.43.0.1      <none>        443/TCP            118s

NAME                                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/keda-admission-webhooks           1/1     1            1           99s
deployment.apps/keda-operator                     1/1     1            1           99s
deployment.apps/keda-operator-metrics-apiserver   1/1     1            1           99s

NAME                                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/keda-admission-webhooks-6dccd9f565          1         1         1       99s
replicaset.apps/keda-operator-6bbd69f48b                    1         1         1       99s
replicaset.apps/keda-operator-metrics-apiserver-bfb497658   1         1         1       99s
```
