## Installing the chart

### Prerequisites

- Kubernetes 1.28+
- Helm 3.7+
- Agentgateway CRDs installed (via `agentgateway-crds-chart`)

### Installation steps

#### Step 1: Install the CRDs chart

```console
helm install agentgateway-crds oci://dhi.io/agentgateway-crds-chart --version 1.2.1 \
  --namespace agentgateway-system --create-namespace
```

#### Step 2: Create a Kubernetes secret for pulling images

```console
kubectl create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<Docker username> \
  --docker-password=<Docker token> \
  --docker-email=<Docker email> \
  -n agentgateway-system
```

#### Step 3: Install the Helm chart

```console
helm install agentgateway oci://dhi.io/agentgateway-chart --version 1.2.1 \
  --namespace agentgateway-system \
  --set "imagePullSecrets[0].name=helm-pull-secret"
```

#### Step 4: Verify the installation

```bash
$ kubectl get pods -n agentgateway-system
NAME                              READY   STATUS    RESTARTS   AGE
agentgateway-6f8b9c7d4f-abc12    1/1     Running   0          30s

$ kubectl get gatewayclass
NAME             CONTROLLER                              ACCEPTED
agentgateway     agentgateway.dev/agentgateway           True
```

For more details, visit the upstream documentation:
https://agentgateway.dev/docs/kubernetes/latest/quickstart/install/
