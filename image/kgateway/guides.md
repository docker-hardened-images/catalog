## Running KGateway

KGateway is typically deployed via its Helm chart. The image contains the control plane binary that manages Envoy Proxy
instances as the data plane.

### Docker Run Example

```bash
docker run --rm dhi.io/kgateway:2.3.0 --help
```

### Kubernetes Deployment

The recommended way to deploy KGateway is via the `kgateway-chart` Helm chart:

```console
helm install kgateway oci://dhi.io/kgateway-chart --version 2.3.0 \
  --namespace kgateway-system --create-namespace \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

### Verifying the Installation

```bash
kubectl get pods -n kgateway-system
kubectl get gatewayclass
```

You should see the `kgateway` GatewayClass registered and the controller pod running.

### Creating a Gateway

Once installed, create a Gateway resource:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: kgateway-system
spec:
  gatewayClassName: kgateway
  listeners:
    - name: http
      port: 8080
      protocol: HTTP
```

For more details, visit the upstream documentation:
https://kgateway.dev/docs/
