## About KAI Scheduler Queue Controller

KAI Scheduler is an open-source Kubernetes scheduler for AI and GPU workloads, originally developed by NVIDIA. Its
hierarchical queues apply quotas, limits, priorities and fairness across the teams that share a cluster.

The queue controller is the KAI Scheduler component that manages those queues. It reconciles `Queue` resources, keeps
their status and child queue lists up to date, exports queue metrics, and validates new and changed queues with an
admission webhook. For more information, see the
[KAI Scheduler repository](https://github.com/kai-scheduler/KAI-Scheduler).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

KAI Scheduler is established as KAI Scheduler a Series of LF Projects, LLC, and is a Cloud Native Computing Foundation
Sandbox project. For its trademark policy, see https://lfprojects.org/policies/. NVIDIA® is a trademark and/or
registered trademark of NVIDIA Corporation. Kubernetes® is a registered trademark of The Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
