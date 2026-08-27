## About Descheduler

Descheduler for Kubernetes evicts pods from nodes based on configurable policies, allowing the default scheduler to
reassign them to nodes that are a better fit. It addresses scheduling decisions that become suboptimal over time as
cluster state changes - for example, when new nodes are added, node labels change, or resource utilization shifts.

Descheduler ships a set of built-in policies such as `RemoveDuplicates`, `LowNodeUtilization`, and
`RemovePodsViolatingNodeAffinity` that can be composed and tuned to match your cluster's rebalancing requirements. It
can run as a Deployment, CronJob, or Job depending on how frequently you want evictions to occur.

Official documentation: https://github.com/kubernetes-sigs/descheduler

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
