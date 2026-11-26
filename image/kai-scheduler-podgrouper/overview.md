## About KAI Scheduler Podgrouper

[KAI Scheduler](https://github.com/kai-scheduler/KAI-scheduler), developed by NVIDIA, is a Kubernetes scheduler for AI
and machine learning workloads that allocates GPU and CPU resources through hierarchical queues and schedules related
pods together.

Podgrouper is the KAI Scheduler controller that prepares workloads for that scheduler. It watches pods that request
`kai-scheduler`, creates a PodGroup for each workload's top owner, such as a Job, Deployment or PyTorchJob, and
annotates each pod with its group, so the scheduler can gang-schedule the workload. The KAI operator deploys it as part
of a KAI Scheduler installation.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

NVIDIA® is a trademark and/or registered trademark of NVIDIA Corporation. Kubernetes® is a registered trademark of The
Linux Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.

This listing is prepared by Docker. All other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
