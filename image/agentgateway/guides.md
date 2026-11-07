## Running Agentgateway

Agentgateway is typically deployed via its Helm chart. The image contains the data plane proxy binary that handles
MCP, A2A, and LLM routing traffic.

### Docker Run Example

```bash
docker run --rm dhi.io/agentgateway:1.2.1 --help
```

### Kubernetes Deployment

The recommended way to deploy agentgateway is via the Helm charts:

```console
# Install CRDs
helm install agentgateway-crds oci://dhi.io/agentgateway-crds-chart --version 1.2.1 \
  --namespace agentgateway-system --create-namespace

# Install control plane
helm install agentgateway oci://dhi.io/agentgateway-chart --version 1.2.1 \
  --namespace agentgateway-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

### Verifying the Installation

```bash
kubectl get pods -n agentgateway-system
kubectl get gatewayclass
```

For more details, visit the upstream documentation:
https://agentgateway.dev/docs/kubernetes/latest/quickstart/install/
