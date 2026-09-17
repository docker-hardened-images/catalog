## Installing the chart

### Prerequisites

- Kubernetes 1.28+
- Helm 3.7+

### Installation

```console
helm install agentgateway-crds oci://dhi.io/agentgateway-crds-chart --version 1.2.1 \
  --namespace agentgateway-system --create-namespace
```

### Verifying the installation

```bash
$ kubectl get crd | grep agentgateway
agentgatewaybackends.gateway.agentgateway.dev    2026-05-20T00:00:00Z
agentgatewayparameters.gateway.agentgateway.dev  2026-05-20T00:00:00Z
agentgatewaypolicies.gateway.agentgateway.dev    2026-05-20T00:00:00Z
```

After installing the CRDs, proceed to install the `agentgateway-chart`:

```console
helm install agentgateway oci://dhi.io/agentgateway-chart --version 1.2.1 \
  --namespace agentgateway-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```
