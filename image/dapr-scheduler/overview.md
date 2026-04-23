## About Dapr Scheduler

Dapr Scheduler is a system service designed to decouple actors and workflows from direct timer management, ensuring
reliability and scalability in distributed applications. It offloads the responsibility of scheduling persistent timers
and reminders from the Dapr sidecar, allowing the system to handle large volumes of long-running stateful operations
efficiently. It is typically deployed as part of a Dapr control-plane installation rather than managed as a standalone
service container.

For deployment and configuration details, see:

- https://docs.dapr.io/operations/components/setup-supported-schedulers/
- https://docs.dapr.io/operations/hosting/kubernetes/kubernetes-overview/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Dapr® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
