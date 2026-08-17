## Installing the chart

### Prerequisites

- Kubernetes 1.34+ cluster
- Helm 3.0+

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
helm install spark oci://dhi.io/spark-kubernetes-operator-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 4: Verify the installation

Check that the release deployed and the operator pod is running:

```console
$ helm list
NAME   NAMESPACE REVISION UPDATED                  STATUS   CHART                             APP VERSION
spark  default   1        2026-08-17 10:00:00.0000 deployed spark-kubernetes-operator-chart-1.0.0 1.0.0
```

With the operator running, submit a `SparkApplication` resource:

```console
$ cat > spark-pi.yaml << 'EOF'
apiVersion: spark.apache.org/v1
kind: SparkApplication
metadata:
  name: pi
spec:
  mainClass: "org.apache.spark.examples.SparkPi"
  jars: "local:///opt/spark/examples/jars/spark-examples.jar"
  runtimeVersions:
    sparkVersion: "4.2.0"
EOF
$ kubectl apply -f spark-pi.yaml
sparkapplication.spark.apache.org/pi created
```

That command created a `SparkApplication` resource which can also be queried to check how the run went:

```console
$ kubectl get sparkapp
NAME   CURRENT STATE      AGE
pi     ResourceReleased   4m10s
```

Clean up the example application once you are done with it:

```console
$ kubectl delete sparkapp pi
sparkapplication.spark.apache.org "pi" deleted
```

Consult the [upstream documentation](https://apache.github.io/spark-kubernetes-operator/) for `SparkCluster` examples,
RBAC customization, and other workload configuration options.

🧹 Uninstall:

```console
$ helm uninstall spark
```

Uninstalling the chart does not remove the CRDs it installed. Remove them explicitly if you no longer need them:

```console
$ kubectl delete crd sparkapplications.spark.apache.org
$ kubectl delete crd sparkclusters.spark.apache.org
```
