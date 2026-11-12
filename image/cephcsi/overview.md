## About Ceph CSI

Ceph CSI is a Container Storage Interface (CSI) driver for Kubernetes that provisions and manages Ceph-backed storage
through RBD, CephFS, NFS, and NVMe-oF workflows. It provides controller and node components for dynamic provisioning,
attachment, expansion, snapshotting, and runtime mount operations.

This hardened image packages the upstream `cephcsi` binary together with the Ceph client libraries and command-line
tools it relies on for cluster-facing operations, including the upstream `ceph` CLI wrapper runtime. The runtime layout
is aligned with the upstream container image while using Docker Hardened Images conventions for provenance, SBOMs, and
minimized package selection.

## About Docker Hardened Images

Docker Hardened Images are built to meet high security and compliance standards. They provide signed provenance, SBOM
metadata, VEX support, and a minimized runtime surface so teams can adopt upstream software with fewer supply-chain and
maintenance surprises.

## Trademarks

Ceph® is a registered trademark of Red Hat, Inc. Any rights therein are reserved to Red Hat, Inc. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
