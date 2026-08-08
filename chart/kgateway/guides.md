## Installing the chart

### Prerequisites

- Kubernetes 1.28+
- Helm 3.7+
- Gateway API CRDs installed (via `kgateway-crds-chart`)

### Installation steps

#### Step 1: Install the CRDs chart

```console
helm install kgateway-crds oci://dhi.io/kgateway-crds-chart --version 2.3.0 \
  --namespace kgateway-system --create-namespace
```

#### Step 2: Create a Kubernetes secret for pulling images

```console
kubectl create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<Docker username> \
  --docker-password=<Docker token> \
  --docker-email=<Docker email> \
  -n kgateway-system
```

#### Step 3: Install the Helm chart

```console
helm install kgateway oci://dhi.io/kgateway-chart --version 2.3.0 \
  --namespace kgateway-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

#### Step 4: Verify the installation

```bash
$ kubectl get pods -n kgateway-system
NAME                        READY   STATUS    RESTARTS   AGE
kgateway-6f8b9c7d4f-abc12  1/1     Running   0          30s

$ kubectl get gatewayclass
NAME       CONTROLLER                    ACCEPTED
kgateway   kgateway.dev/kgateway         True
```

### Creating a Gateway

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
