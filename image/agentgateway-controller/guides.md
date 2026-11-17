## Running Agentgateway Controller

The agentgateway controller is deployed as part of the `agentgateway-chart` Helm chart. It manages the agentgateway
data plane proxy pods.

### Docker Run Example

```bash
docker run --rm dhi.io/agentgateway-controller:1.2.1 --help
```

### Kubernetes Deployment

Deploy via the Helm chart:

```console
helm install agentgateway oci://dhi.io/agentgateway-chart --version 1.2.1 \
  --namespace agentgateway-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

For more details, visit the upstream documentation:
https://agentgateway.dev/docs/kubernetes/latest/quickstart/install/
