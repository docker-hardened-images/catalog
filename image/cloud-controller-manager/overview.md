## About Kubernetes Cloud Controller Manager (cloud-controller-manager)

cloud-controller-manager runs the Kubernetes control loops that are specific to the underlying cloud provider. It embeds
cloud-specific controllers — such as the node, route, and service controllers — that let a Kubernetes cluster integrate
with a cloud provider's APIs, decoupling that integration from the core control plane binaries.

Use this image when you need a hardened, minimal container image for running the Kubernetes cloud controller manager as
part of a Kubernetes control plane deployment.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. Any use by Docker is for referential purposes only and
does not indicate sponsorship, endorsement, or affiliation.
