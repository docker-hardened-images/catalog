## About SPIFFE CSI Driver

The [SPIFFE CSI Driver](https://spiffe.io/) is a
[Container Storage Interface (CSI)](https://github.com/container-storage-interface/spec/blob/master/spec.md) driver for
Kubernetes that facilitates injection of the SPIFFE Workload API socket into workload pods as an ephemeral inline
volume. The SPIFFE Workload API is served over a Unix domain socket; implementations such as
[SPIRE](https://github.com/spiffe/spire) rely on DaemonSets to run one Workload API server instance per node. The
primary motivation for using a CSI driver is to avoid the use of `hostPath` volumes in workload containers, which is
commonly disallowed or restricted by policy due to inherent security concerns.

The driver mounts a directory containing the SPIFFE Workload API socket — provided by a SPIFFE implementation such as
SPIRE — as a read-only bind mount into workload pods at the requested target path. When a pod declares an ephemeral
inline volume using this driver, the driver is invoked to perform the bind mount; when the pod is destroyed, the driver
removes it. This lifecycle management ensures workloads always have access to a valid Workload API socket without
requiring elevated privileges or direct `hostPath` access in the workload containers themselves.

The SPIFFE CSI Driver is typically deployed as a container in the same DaemonSet that runs the SPIRE Agent, registered
with the kubelet using the CSI Node Driver Registrar sidecar. CSI Ephemeral Inline Volumes require at least Kubernetes
1.15 (via the `CSIInlineVolume` feature gate) or Kubernetes 1.16 and later where the feature is enabled by default. The
project is currently in the
[pre-production phase](https://github.com/spiffe/spiffe/blob/main/MATURITY.md#pre-production) of the SPIFFE maturity
model.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Spiffe® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
