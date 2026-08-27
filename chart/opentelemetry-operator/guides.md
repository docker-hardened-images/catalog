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

#### Step 3: Install cert-manager (or disable it)

By default the OpenTelemetry Operator chart uses [cert-manager](https://cert-manager.io/) to issue the TLS certificate
for its admission webhooks. If cert-manager is not already installed in your cluster, install it first:

```console
helm registry login dhi.io
helm install cert-manager oci://dhi.io/cert-manager-chart --version 1.20.2 \
  --namespace cert-manager --create-namespace \
  --set "global.imagePullSecrets[0].name=helm-pull-secret" \
  --set "crds.enabled=true"
```

Replace `1.20.2` with the cert-manager chart version that matches your OpenTelemetry Operator chart release. Use the
same `helm-pull-secret` name you created in Step 2.

Alternatively, you can disable cert-manager and let the chart auto-generate a self-signed certificate by passing
`--set admissionWebhooks.certManager.enabled=false` in the install command in Step 4.

#### Step 4: Install the Helm chart

```console
helm install my-otel-operator oci://dhi.io/opentelemetry-operator-chart --version <version> \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

Replace `<version>` accordingly. If the chart is in your own registry or repository, replace `dhi.io` with your own
registry and namespace. Replace `helm-pull-secret` with the name of the image pull secret you created earlier.

#### Step 5: Verify the installation

The operator pod should show up and become ready shortly:

```bash
kubectl get pods -l app.kubernetes.io/name=opentelemetry-operator
```

Verify the custom resource definitions are installed:

```bash
kubectl get crds | grep opentelemetry.io
```

You should see resources such as `opentelemetrycollectors.opentelemetry.io` and `instrumentations.opentelemetry.io`.

#### Step 6: Create an OpenTelemetryCollector

Once the operator is running, you can create an `OpenTelemetryCollector` custom resource to deploy a collector managed
by the operator:

```yaml
# otel-collector.yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: simplest
spec:
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    exporters:
      debug: {}
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [debug]
```

Apply it:

```console
kubectl apply -f otel-collector.yaml
```

The operator will reconcile the resource and create a Deployment running the collector image configured in the chart.

For more usage examples (sidecar mode, auto-instrumentation, target allocator), see the
[upstream operator documentation](https://github.com/open-telemetry/opentelemetry-operator).
