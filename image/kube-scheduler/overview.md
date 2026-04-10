## About kube-scheduler

kube-scheduler assigns newly created Pods to nodes. It watches for Pods without a scheduled node, evaluates node
feasibility and scoring (including taints/tolerations, affinities, and resource constraints), and binds Pods to the
selected node.

Use this image when you need a hardened, minimal container image for running the Kubernetes scheduler as part of a
Kubernetes control plane deployment.

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
