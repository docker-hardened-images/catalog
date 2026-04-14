## About Istio Proxy v2

Istio Proxy v2 is a next-generation service mesh sidecar proxy that combines an enhanced Envoy proxy with intelligent
traffic management capabilities. It serves as the data plane component of the Istio service mesh, providing advanced
networking, security, and observability features for microservices running in Kubernetes.

The proxy consists of two main components working together:

- **Enhanced Envoy Proxy**: A customized build of the Envoy proxy with Istio-specific extensions for telemetry,
  authentication, and traffic management
- **Pilot Agent**: An intelligent management layer that handles configuration, certificate management, and lifecycle
  operations

Key capabilities of Istio Proxy v2:

- **Intelligent Traffic Management**: Advanced load balancing, circuit breaking, retries, timeouts, and traffic
  splitting capabilities
- **Zero-Trust Security**: Automatic mutual TLS (mTLS) encryption between services with certificate management and
  rotation
- **Rich Telemetry**: Comprehensive metrics, distributed tracing, and access logging for deep observability into service
  communications
- **Policy Enforcement**: Fine-grained access control and rate limiting policies
- **Service Discovery**: Automatic discovery and configuration of services in the mesh
- **Health Monitoring**: Sophisticated health checking and failure detection
- **Protocol Support**: HTTP/1.1, HTTP/2, gRPC, TCP, and WebSocket protocols

This image is designed specifically for **sidecar injection** in Kubernetes environments and requires the Istio control
plane (Istiod) to function. It cannot operate as a standalone proxy and is not intended for direct execution outside of
the Istio service mesh context.

The proxy automatically intercepts all network traffic to and from the application container in the same pod, providing
transparent service mesh capabilities without requiring application code changes.

For more information about Istio, visit https://istio.io/latest/docs/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no
affiliation,sponsorship, or endorsement is implied.
