## Installing the chart

### Prerequisites

- Kubernetes 1.26+
- Helm 3.7+
- A PostgreSQL database (version 13+) accessible from your cluster

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

#### Step 3: Install the Helm chart

This chart requires an external PostgreSQL database (version 13+). The built-in PostgreSQL subchart from the upstream
Airflow chart has been removed. You must provision your own PostgreSQL instance and provide the connection details as
described below.

Create a Kubernetes secret with the connection string before installing:

```console
kubectl create secret generic airflow-metadata \
  --from-literal=connection="postgresql+psycopg2://<user>:<password>@<host>:<port>/<db>"
```

To install the chart, use `helm install`. Make sure you use `helm login` to log in before running `helm install`.
Optionally, you can also use the `--dry-run` flag to test the installation without actually installing anything.

```console
helm install my-airflow oci://dhi.io/airflow-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret" \
  --set data.metadataSecretName=airflow-metadata \
  --set webserverSecretKey=$(python3 -c 'import secrets; print(secrets.token_hex(16))')
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

After installing, verify that all Airflow pods are running:

```bash
$ kubectl get pods
NAME                                            READY   STATUS    RESTARTS   AGE
my-airflow-scheduler-0                          2/2     Running   0          3m
my-airflow-triggerer-0                          2/2     Running   0          3m
my-airflow-api-server-6c8b4d9f5d-xpq2k          1/1     Running   0          3m
```

You can access the Airflow UI by port-forwarding the webserver:

```bash
kubectl port-forward svc/my-airflow-api-server 8080:8080
```

Then open http://localhost:8080 in your browser. The default credentials are `admin` / `admin` unless configured
otherwise.

#### Security context

This chart defaults to running all Airflow components with UID 50000 and GID 50000, matching the DHI Airflow image which
is built with that user and group. This differs from the upstream Apache Airflow Helm chart, which defaults to GID 0 for
OpenShift compatibility (OpenShift runs containers with arbitrary UIDs but always GID 0).

If you are deploying on OpenShift, you may need to override the group IDs back to 0:

```console
helm install my-airflow oci://dhi.io/airflow-chart --version <version> \
  --set "securityContexts.pod.runAsGroup=0" \
  --set "securityContexts.pod.fsGroup=0"
```
