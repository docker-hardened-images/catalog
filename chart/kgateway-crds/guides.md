## Installing the chart

### Prerequisites

- Kubernetes 1.28+
- Helm 3.7+

### Installation

```console
helm install kgateway-crds oci://dhi.io/kgateway-crds-chart --version 2.3.0 \
  --namespace kgateway-system --create-namespace
```

### Verifying the installation

```bash
$ kubectl get crd | grep kgateway
gatewayparameters.gateway.kgateway.dev   2026-05-20T00:00:00Z
```

After installing the CRDs, proceed to install the `kgateway-chart`:

```console
helm install kgateway oci://dhi.io/kgateway-chart --version 2.3.0 \
  --namespace kgateway-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```
