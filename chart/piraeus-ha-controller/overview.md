## About this Helm chart

This is a Piraeus HA Controller Docker Hardened Helm chart built from the upstream Piraeus HA Controller Helm chart and
using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Image is used in this Helm chart:

- `dhi/piraeus-ha-controller`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/piraeusdatastore/helm-charts/tree/main/charts/piraeus-ha-controller](https://github.com/piraeusdatastore/helm-charts/tree/main/charts/piraeus-ha-controller)

**Note**: This chart is deprecated by upstream. The HA controller functionality is now integrated into the Piraeus
Operator chart.

## About Piraeus HA Controller

The Piraeus HA Controller is a Kubernetes controller that monitors DRBD-backed storage volumes and accelerates failover
of stateful workloads when storage issues occur. By leveraging DRBD's quorum mechanism, it can safely force-delete pods
and detach volumes within seconds, reducing failover time from the default 15+ minutes to approximately 10 seconds.

When a node loses quorum on its DRBD resources, the HA controller automatically taints the node, evicts affected pods,
and force-detaches volumes, allowing Kubernetes to reschedule workloads to healthy nodes immediately. This is
particularly valuable for mission-critical stateful applications like databases where rapid recovery is essential.

The controller runs as a DaemonSet on all nodes with DRBD resources and requires privileged access to interact with the
DRBD kernel module. It continuously monitors quorum status and responds to storage failures without manual intervention.

For more information and documentation see
[https://github.com/piraeusdatastore/piraeus-ha-controller](https://github.com/piraeusdatastore/piraeus-ha-controller).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Piraeus is a trademark of LINBIT. All rights in the mark are reserved to LINBIT. Any use by Docker is for referential
purposes only and does not indicate sponsorship, endorsement, or affiliation.
