## Installing the chart

### Prerequisites

- Kubernetes 1.24+ (recommended 1.30+)
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

Before installing the Helm chart you will need to setup a ClusterRole and a ClusterRoleBinding so that the job that
invokes `kube-webhook-certgen` can generate a certificate. This can be done with the snipped below. You might need to
adapt the names slightly if you change the name of the release when installing the Helm chart.

```bash
kubectl create namespace vpa

kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: vpa-admission-certgen-webhook-patch
rules:
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["mutatingwebhookconfigurations", "validatingwebhookconfigurations"]
  verbs: ["get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vpa-admission-certgen-webhook-patch
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: vpa-admission-certgen-webhook-patch
subjects:
- kind: ServiceAccount
  name: vpa-fairwinds-vpa-chart-admission-certgen
  namespace: vpa
YAML
```

Then, to install the chart, use `helm install`. Make sure you use `helm login` to log in before running `helm install`.
Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

```console
helm install vpa oci://dhi.io/fairwinds-vpa-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" --namespace vpa
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

The deployment's pods should show up and running almost immediately:

```bash
$ kubectl get all -n vpa
NAME                                                              READY   STATUS    RESTARTS   AGE
pod/vpa-fairwinds-vpa-chart-admission-controller-ccd4c66d-fl52g   1/1     Running   0          43s
pod/vpa-fairwinds-vpa-chart-recommender-7b95788d89-9rqg2          1/1     Running   0          43s
pod/vpa-fairwinds-vpa-chart-updater-5cbbc55c58-xrldc              1/1     Running   0          43s

NAME                                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/vpa-fairwinds-vpa-chart-webhook   ClusterIP   10.43.201.248   <none>        443/TCP   43s

NAME                                                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/vpa-fairwinds-vpa-chart-admission-controller   1/1     1            1           43s
deployment.apps/vpa-fairwinds-vpa-chart-recommender            1/1     1            1           43s
deployment.apps/vpa-fairwinds-vpa-chart-updater                1/1     1            1           43s

NAME                                                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/test-fairwinds-vpa-chart-admission-controller-ccd4c66d   1         1         1       43s
replicaset.apps/test-fairwinds-vpa-chart-recommender-7b95788d89          1         1         1       43s
replicaset.apps/test-fairwinds-vpa-chart-updater-5cbbc55c58              1         1         1       43s
```
