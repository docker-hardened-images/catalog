# cloudflared Deployment Guide

`cloudflared` runs as a daemon inside your cluster or network environment to securely tunnel traffic to Cloudflare.

## Docker Run Example

You can run `cloudflared` in a container to connect a tunnel:

```bash
docker run -d --name cloudflared-tunnel \
  dhi.io/cloudflared:2026.1.2 \
  tunnel --no-autoupdate run --token <your-tunnel-token>
```

## Kubernetes Deployment Example

Deploy `cloudflared` as a deployment to manage tunnels in your Kubernetes cluster:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: dhi.io/cloudflared:2026.1.2
        args:
        - tunnel
        - --no-autoupdate
        - run
        - --token
        - <your-tunnel-token>
        securityContext:
          runAsUser: 65532
          runAsGroup: 65532
          runAsNonRoot: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          seccompProfile:
            type: RuntimeDefault
```
