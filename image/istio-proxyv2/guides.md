## How to use this image

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository** > **Mirror to
repository**, and then follow the on-screen instructions.

## Start an Istio Proxy v2 container

The Istio Proxy v2 image is designed as a **sidecar container** and requires the Istio service mesh control plane to
function. It cannot be run standalone. This image is typically deployed through automatic sidecar injection in
Kubernetes environments with Istio installed.

Replace `<your-namespace>` with your organization's namespace and `<tag>` with the image variant you want to use. To
confirm the correct namespace and repository name of the mirrored repository, select **View in repository**.

## Common Istio Proxy v2 use cases

### Service mesh sidecar deployment

The primary use case is automatic sidecar injection in Kubernetes pods within an Istio service mesh:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productpage-v1
  labels:
    app: productpage
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productpage
      version: v1
  template:
    metadata:
      labels:
        app: productpage
        version: v1
    spec:
      containers:
      - name: productpage
        image: docker.io/istio/examples-bookinfo-productpage-v1:1.16.2
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
```

With automatic sidecar injection enabled (via namespace annotation `istio-injection=enabled`), the proxy sidecar is
automatically added.

## Non-hardened images vs. Docker Hardened Images

Key differences specific to the Istio Proxy v2 DHI:

- **Security hardening**: The DHI version includes additional security configurations and runs with a non-root user by
  default
- **Minimal attack surface**: Contains only essential components needed for proxy functionality
- **Enhanced monitoring**: Built-in SBOM and vulnerability scanning capabilities
- **Compliance ready**: Meets enterprise security and compliance requirements
- **Certificate validation**: Enhanced certificate chain validation and management
- **No debugging tools**: Runtime images exclude debugging utilities for security; use Docker Debug for troubleshooting

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

### Runtime variants

Designed to run your proxy in production. These images are intended to be used directly in Kubernetes deployments. These
images typically:

- Run as a nonroot user (UID 1337)
- Do not include a shell or package manager
- Contain only the minimal set of libraries needed to run the proxy
- Include pilot-agent and enhanced Envoy proxy

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. Docker Hardened Python images include FIPS-compliant variants for environments requiring
Federal Information Processing Standards compliance.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your Istio deployment to use Docker Hardened Images, you must update your Istio installation configuration.
This typically involves updating the proxy image in your Istio operator configuration or installation manifests.

| Item                   | Migration note                                                                                      |
| :--------------------- | :-------------------------------------------------------------------------------------------------- |
| Base image             | Replace the standard istio/proxyv2 image with the Docker Hardened Image in your Istio configuration |
| Security context       | Ensure the security context allows running as UID 1337 (the istio-proxy user)                       |
| Volume mounts          | Verify all required volume mounts are configured for certificates, tokens, and configuration        |
| Network policies       | Update any network policies to account for the hardened image's security constraints                |
| Monitoring             | Update monitoring configuration to work with the hardened image's metrics endpoints                 |
| Certificate management | Ensure certificate paths and permissions are compatible with the nonroot user                       |

The following steps outline the migration process:

1. **Update Istio installation**

   Modify your Istio installation to use the Docker Hardened Image. For IstioOperator:

   ```yaml
   apiVersion: install.istio.io/v1alpha1
   kind: IstioOperator
   metadata:
     name: control-plane
   spec:
     values:
       global:
         proxy:
           image: <your-namespace>/dhi-istio-proxyv2:<tag>
   ```

1. **Verify security contexts**

   Ensure your deployment allows the proxy to run as the nonroot user:

   ```yaml
   securityContext:
     runAsUser: 1337
     runAsGroup: 1337
     fsGroup: 1337
   ```

1. **Update volume permissions**

   Verify that mounted volumes have appropriate permissions for the nonroot user:

   ```yaml
   volumes:
   - name: istio-certs
     secret:
       secretName: istio-certs
       defaultMode: 0644
   ```

1. **Configure network policies**

   Update network policies to accommodate the hardened proxy:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: istio-proxy-policy
   spec:
     podSelector:
       matchLabels:
         security.istio.io/tlsMode: istio
     policyTypes:
     - Ingress
     - Egress
   ```

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions and security context

The Istio Proxy v2 DHI runs as user ID 1337 (istio-proxy). Ensure that:

- Volume mounts have appropriate permissions (typically 0644 for files, 0755 for directories)
- Security contexts in your pod specifications allow running as UID 1337
- File ownership is correctly set for configuration and certificate files

### Certificate and authentication issues

Common certificate-related problems:

- **Missing service account tokens**: Ensure the `istio-token` volume is properly mounted
- **Certificate permission errors**: Verify certificate files are readable by UID 1337
- **CA connectivity**: Check that the proxy can reach the Istiod certificate authority
- **Workload certificate rotation**: Ensure the certificate rotation process works with nonroot user

### Network connectivity

Networking issues specific to the hardened proxy:

- **Port binding**: The proxy may need to bind to specific ports for intercept functionality
- **iptables rules**: Verify that traffic interception rules work with the security context
- **Service mesh communication**: Ensure mTLS certificates are properly configured

### Configuration and bootstrap

Configuration-related troubleshooting:

- **Bootstrap template**: Verify the Envoy bootstrap configuration is generated correctly
- **XDS connectivity**: Check connectivity to the Istiod discovery service
- **Environment variables**: Ensure required environment variables are set correctly
- **Metadata extraction**: Verify that pod and service metadata is accessible

### Monitoring and observability

Observability issues in the hardened environment:

- **Metrics collection**: Update Prometheus configuration for the hardened proxy's metrics endpoints
- **Log collection**: Ensure log aggregation systems can access proxy logs
- **Tracing configuration**: Verify distributed tracing works with the security constraints
- **Health check endpoints**: Confirm readiness and liveness probes function correctly

### Entry point and command differences

The hardened Istio Proxy v2 image may have different entry points than the upstream image:

- **Pilot-agent start**: The proxy starts via pilot-agent, not directly via Envoy
- **Signal handling**: Process lifecycle management may differ from the upstream image
- **Graceful shutdown**: Ensure proper shutdown sequences work in your environment

To verify the entry point for an image variant, select the **Tags** tab for this repository, select a tag, and then
select the **Specifications** tab.
