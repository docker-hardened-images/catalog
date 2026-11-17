## About drbd-reactor

drbd-reactor is a user-space daemon that monitors DRBD (Distributed Replicated Block Device) resources and executes
actions based on state changes. It provides event-driven resource management for DRBD storage systems, enabling
automated responses to resource state transitions such as promotion, demotion, and synchronization events. The daemon is
typically deployed as a sidecar container in Kubernetes pods alongside DRBD-enabled applications, where it monitors DRBD
resources and triggers configured actions when resource states change. drbd-reactor integrates with the DRBD utilities
(drbdadm, drbdsetup) to provide comprehensive resource management capabilities for high-availability storage
deployments.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

DRBD® is a registered trademark of LINBIT HA-Solutions GmbH. All rights in the mark are reserved to LINBIT HA-Solutions
GmbH. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
