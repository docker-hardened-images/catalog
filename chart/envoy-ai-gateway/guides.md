## Installing the chart

### Prerequisites

- Kubernetes 1.32+
- Helm 3.7+
- Envoy Gateway installed
- Envoy AI Gateway CRDs installed (via `envoy-ai-gateway-crds-chart`)

### Installation steps

#### Step 1: Install the CRDs chart

```console
helm install envoy-ai-gateway-crds oci://dhi.io/envoy-ai-gateway-crds-chart --version 0.7.0 \
  --namespace envoy-ai-gateway-system --create-namespace
```

#### Step 2: Create a Kubernetes secret for pulling images

```console
kubectl create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<Docker username> \
  --docker-password=<Docker token> \
  --docker-email=<Docker email> \
  -n envoy-ai-gateway-system
```

#### Step 3: Install the Helm chart

```console
helm install envoy-ai-gateway oci://dhi.io/envoy-ai-gateway-chart --version 0.7.0 \
  --namespace envoy-ai-gateway-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

#### Step 4: Verify the installation

```bash
$ kubectl get pods -n envoy-ai-gateway-system
NAME                                  READY   STATUS    RESTARTS   AGE
ai-gateway-controller-6f8b9c7d4f-x    1/1     Running   0          30s
```

For more details, visit the upstream documentation:
https://aigateway.envoyproxy.io/docs/
