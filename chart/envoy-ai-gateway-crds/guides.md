## Installing the chart

### Prerequisites

- Kubernetes 1.32+
- Helm 3.7+
- Envoy Gateway installed

### Installation

```console
helm install envoy-ai-gateway-crds oci://dhi.io/envoy-ai-gateway-crds-chart --version 0.7.0 \
  --namespace envoy-ai-gateway-system --create-namespace
```

### Verifying the installation

```bash
$ kubectl get crd | grep aigateway.envoyproxy.io
aigatewayroutes.aigateway.envoyproxy.io        2026-06-04T00:00:00Z
aiservicebackends.aigateway.envoyproxy.io      2026-06-04T00:00:00Z
backendsecuritypolicies.aigateway.envoyproxy.io 2026-06-04T00:00:00Z
```

After installing the CRDs, proceed to install the `envoy-ai-gateway-chart`:

```console
helm install envoy-ai-gateway oci://dhi.io/envoy-ai-gateway-chart --version 0.7.0 \
  --namespace envoy-ai-gateway-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```
