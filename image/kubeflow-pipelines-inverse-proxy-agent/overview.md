## About Kubeflow Pipelines - Inverse Proxy Agent

The Kubeflow Pipelines inverse proxy agent makes the Kubeflow Pipelines UI in a Google Kubernetes Engine (GKE) cluster
reachable through Google's inverting proxy, without exposing a public endpoint or load balancer. It runs as a single pod
next to the Pipelines UI Service and keeps an outbound connection to the proxy, which relays browser requests back to
the UI.

On startup, the launcher reuses the proxy registration stored in the `inverse-proxy-config` ConfigMap, or registers a
new backend using the node's Google Cloud identity and records the result there. See the
[Kubeflow Pipelines documentation](https://www.kubeflow.org/docs/components/pipelines/) for details.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubeflow® is a trademark of the Linux Foundation. Google Cloud™ is a trademark of Google LLC. All rights in the marks
are reserved to their respective owners. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation.
