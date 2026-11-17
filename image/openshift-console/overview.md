## About the console for Red Hat OpenShift

This image packages the web-based management console (codename "Bridge") used by Red Hat® OpenShift® and OKD clusters.
Its Go backend server serves the compiled React/TypeScript frontend and proxies authenticated requests to the Kubernetes
API server, OAuth, and in-cluster services such as Prometheus, Alertmanager, Thanos, and GitOps, giving cluster
operators and developers a single UI for managing workloads, monitoring cluster health, and administering Operator
Lifecycle Manager (OLM) operators.

The console is designed to run inside a Kubernetes/OpenShift cluster and is normally deployed and managed by the
OpenShift console-operator, which supplies its TLS certificates, OAuth client configuration, and other cluster-specific
settings.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Red Hat® and OpenShift® are trademarks of Red Hat, LLC, registered in the United States and other countries. Docker's
use of these marks is for identification purposes only and does not indicate sponsorship, endorsement, or affiliation
with Red Hat. All other trademarks are the property of their respective owners.
