## How to use this chart

This guide explains how to install and configure the hardened Tailscale Kubernetes Operator Helm chart.

### Installation

To install the chart with the release name `tailscale-operator`:

```bash
helm install tailscale-operator oci://dhi.io/tailscale-operator-chart
```

### Configuration

The hardened Tailscale Operator chart supports the standard configuration options from the upstream chart, with
security-hardened defaults. Key configuration areas include:

- `oauth`: Tailscale OAuth client credentials.
- `operatorConfig`: Configuration for the operator deployment (image, resources, security context).
- `proxyConfig`: Default configuration for proxies created by the operator.

### Hardened Defaults

This chart includes several security-focused defaults:

- **Non-root Execution**: The operator and proxies run as user/group `65532`.
- **Minimal Images**: Uses hardened, minimal base images with zero-known CVEs.
- **Relocated Images**: Automatically pulls from the secure `dhi.io` registry.

### Authentication

To authenticate the operator with your tailnet, you should provide an OAuth client ID and secret:

```yaml
oauth:
  clientId: "YOUR_CLIENT_ID"
  clientSecret: "YOUR_CLIENT_SECRET"
```

Alternatively, you can use an existing secret:

```yaml
oauth:
  secretName: "tailscale-auth"
```

For detailed configuration options, refer to the `values.yaml` and the
[Tailscale Kubernetes documentation](https://tailscale.com/kb/1236/kubernetes-operator).
