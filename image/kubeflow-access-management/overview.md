## About Kubeflow Access Management

Kubeflow Access Management (KFAM) is the API server that manages per-namespace user access in Kubeflow. When a profile
owner shares a namespace, KFAM creates or deletes the RoleBindings and Istio AuthorizationPolicies that grant that
access.

Use it in a Kubeflow multi-user installation that needs namespace sharing through an API. The project is documented at
https://github.com/kubeflow/dashboard/tree/main/components/access-management.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

KubeFlow® is a registered trademark of The Linux Foundation. Kubernetes® is a registered trademark of The Linux
Foundation. Istio® is a registered trademark of The Linux Foundation. All rights in these marks are reserved to The
Linux Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
