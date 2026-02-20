## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/prometheus-adapter:<tag>`
- Mirrored image: `<your-namespace>/dhi-prometheus-adapter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Prometheus Adapter image

This Docker Hardened Image provides the Prometheus Adapter binary (`/adapter`) that implements the Kubernetes Custom and
External Metrics APIs using Prometheus as the backend. The adapter is intended to run inside a Kubernetes cluster where
it can use in-cluster configuration to access the API server and your Prometheus instance.

## Running the adapter

Prometheus Adapter is designed to run in a Kubernetes cluster as part of the custom metrics pipeline. Standalone
`docker run` is only useful for checking the binary (for example `--help` or `--version`); the adapter will not serve
metrics without cluster and Prometheus access.

### Deploy on Kubernetes with the community Helm chart

The recommended way to run Prometheus Adapter is via the
[prometheus-community/prometheus-adapter](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-adapter)
Helm chart, overriding the image to use the Docker Hardened Image.

Prerequisites:

- Kubernetes 1.29+
- Helm 3.6+
- Prometheus deployed in the cluster (for the adapter to query)

Install and use the DHI image:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-adapter prometheus-community/prometheus-adapter \
  --namespace monitoring \
  --create-namespace \
  --set image.registry=dhi.io \
  --set image.repository=prometheus-adapter \
  --set image.tag=<tag> \
  --set image.pullSecrets[0].name=<your-registry-secret> \
  --set prometheus.url=http://prometheus.monitoring.svc:9090
```

Replace `<tag>` with the desired image tag and `<your-registry-secret>` with your
[Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) for `dhi.io`. Adjust `prometheus.url` to match
your Prometheus service.

Verify the deployment:

```bash
kubectl get deployment -n monitoring prometheus-adapter
kubectl get apiservice v1beta1.custom.metrics.k8s.io -o wide
```

### Deploy with the DHI Prometheus Adapter chart

If you use the Docker Hardened Images Prometheus Adapter chart (which packages the same upstream chart with DHI
defaults), the image is already set to `dhi/prometheus-adapter`. Install with:

```bash
helm install my-prometheus-adapter dhi.io/prometheus-adapter-chart:<version> \
  -n monitoring --create-namespace
```

See the chart’s documentation for values and Prometheus URL configuration.

### Example: HPA using custom metrics

After the adapter is running and the Custom Metrics API is available, you can create an HPA that scales on a Prometheus
metric. The adapter must be configured with rules that map Prometheus metrics to the custom metrics API (see
[upstream config documentation](https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/config.md)). For
example, an HPA that scales on `http_requests_per_second`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Prometheus Adapter   | Docker Hardened Prometheus Adapter         |
| --------------- | --------------------------------- | ------------------------------------------ |
| Base image      | Standard base with full utilities | Hardened Debian base                       |
| Security        | Standard image, basic utilities   | Hardened build, security patches, metadata |
| Shell access    | Shell available                   | No shell (runtime variants)                |
| Package manager | Package manager available         | No package manager (runtime variants)      |
| User            | Often root or custom user         | Runs as nonroot user                       |
| Attack surface  | Full OS utilities                 | Only adapter binary and minimal deps       |
| Debugging       | Shell and standard tools          | Use Docker Debug or image mount            |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: runtime containers are not modified after deployment
- Compliance ready: meets strict security requirements for regulated environments

The hardened runtime image does not include a shell or debugging tools. To troubleshoot, use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) or an image mount to attach debugging tools.

Example with Docker Debug:

```bash
docker run -d --name adapter-test dhi.io/prometheus-adapter:<tag>
docker debug adapter-test
# inside debug session: inspect files, env, etc.
docker rm -f adapter-test
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

### Runtime variants

Runtime variants are for running the adapter in production. They typically:

- Run as the nonroot user (UID 65532)
- Do not include a shell or package manager
- Contain only the minimal set of libraries needed to run the adapter

Use these when deploying with Helm or Kubernetes manifests.

To view the image variants and details, select the **Tags** tab for this repository and then select a tag.

## Migrate to a Docker Hardened Image

To migrate from a non-hardened Prometheus Adapter image to a Docker Hardened Image:

| Item          | Migration note                                                                                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image    | Replace the adapter image in your Helm values or manifests with `dhi.io/prometheus-adapter:<tag>`.                                                                              |
| Non-root user | By default, the DHI image runs as a nonroot user. Ensure volumes and permissions (e.g. for TLS or config) are compatible; the upstream chart typically handles this.            |
| Ports         | The adapter’s secure port is typically 6443. Non-root images cannot bind to ports below 1024; the standard chart uses a high port.                                              |
| Entrypoint    | The image entrypoint is `/adapter`. If your manifests override the command, keep args compatible with the upstream adapter (e.g. `--cert-dir`, `--prometheus-url`, `--config`). |
| No shell      | Runtime images do not include a shell. Use Docker Debug for ad-hoc debugging; use Helm/Kubernetes tooling for logs and exec where a shell is expected.                          |

Steps:

1. **Choose a tag** Pick the DHI image tag (e.g. `0.12.0-debian13-0`) from the **Tags** tab.

1. **Update Helm or manifests** Set `image.registry`, `image.repository`, and `image.tag` (and digest if desired) to the
   DHI image. Add `image.pullSecrets` if required for `dhi.io`.

1. **Point to Prometheus** Configure `prometheus.url` (or equivalent) so the adapter can reach your Prometheus server.

1. **Configure metric rules** Keep or adjust the adapter’s rules (ConfigMap or chart values) so the correct Prometheus
   metrics are exposed to the Custom/External Metrics APIs.

## Troubleshooting

### General debugging

Runtime images do not include a shell. Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach
to a container and inspect files, environment, and processes.

### Permissions

The image runs as a nonroot user. If the adapter fails to read config or certificates, check volume mounts and file
ownership in your Helm values or Pod spec.

### API not available

If `kubectl get apiservice v1beta1.custom.metrics.k8s.io` shows as not available, check:

- The adapter Deployment is running and its Pods are Ready.
- The adapter can reach the Kubernetes API server and Prometheus (network policies, service names, ports).
- Adapter logs: `kubectl logs -n monitoring deployment/prometheus-adapter -c prometheus-adapter`.

### Entrypoint and flags

To see the image entrypoint and default command:

```bash
docker inspect dhi.io/prometheus-adapter:<tag> --format '{{json .Config.Entrypoint}}'
```

For supported flags, run:

```bash
docker run --rm dhi.io/prometheus-adapter:<tag> --help
```
