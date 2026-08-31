## About Forklift API

Forklift API is the API server component of [Forklift](https://github.com/kubev2v/forklift), the toolkit for migrating
virtual machines from VMware, oVirt, OpenStack, Hyper-V, OVA, and EC2 to KubeVirt. It serves the mutating and validating
admission webhooks that Kubernetes calls when Forklift custom resources such as `Plan`, `Provider`, `Hook`, and `Secret`
are created or updated.

Alongside the webhooks, it exposes auxiliary HTTP services that the Forklift controller calls during a migration. Both
listeners require TLS material supplied through environment variables, so the process is normally deployed by the
Forklift operator inside a Kubernetes cluster.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

KubeVirt® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
