## About DRBD Shutdown Guard

DRBD Shutdown Guard is an init-container utility designed to ensure DRBD resources are properly handled during system
shutdown in Kubernetes environments. It installs a systemd unit that runs during shutdown to execute
`drbdsetup secondary --force`, ensuring that systemd can unmount all volumes even with `suspend-io` enabled.

This utility is part of the Piraeus Datastore project and is typically used with LinstorSatellite pods to prevent data
corruption during pod termination.

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
