## About Kubeflow Central Dashboard

Kubeflow Central Dashboard is the web UI of a Kubeflow installation. It links the component UIs such as Notebooks,
Pipelines and Katib, and shows each user's namespaces, recent activity and resources, using the Kubernetes API and the
Kubeflow Access Management (KFAM) API.

This image runs the dashboard server and replaces the upstream `ghcr.io/kubeflow/dashboard/dashboard` image. The project
is documented at https://github.com/kubeflow/dashboard/tree/main/components/centraldashboard.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

KubeFlow® is a registered trademark of The Linux Foundation. Kubernetes® is a registered trademark of The Linux
Foundation. All rights in these marks are reserved to The Linux Foundation. Any use by Docker is for referential
purposes only and does not indicate sponsorship, endorsement, or affiliation.
