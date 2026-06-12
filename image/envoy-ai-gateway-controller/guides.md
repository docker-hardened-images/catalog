## Running Envoy AI Gateway Controller

The controller is deployed as part of the `envoy-ai-gateway-chart` Helm chart. It runs on top of Envoy Gateway and
manages the AI Gateway custom resources.

### Docker Run Example

```bash
docker run --rm dhi.io/envoy-ai-gateway-controller:0.7.0 --help
```

### Kubernetes Deployment

Deploy via the Helm chart:

```console
helm install ai-gateway oci://dhi.io/envoy-ai-gateway-chart --version 0.7.0 \
  --namespace envoy-ai-gateway-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

For more details, visit the upstream documentation:
https://aigateway.envoyproxy.io/docs/
