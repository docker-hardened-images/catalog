## About Forklift Operator Index

Forklift is the upstream project behind Red Hat Migration Toolkit for Virtualization (MTV), part of the
[Konveyor](https://konveyor.io/) community. It migrates virtual machines at scale to Kubernetes KubeVirt/OpenShift
Virtualization from source providers such as VMware vSphere, oVirt, OpenStack, and OVA, using a choreographed plan of
credentials, infrastructure mapping, and execution steps.

This image is an [OLM](https://olm.operatorframework.io/) File-Based Catalog (FBC) index: it serves the
[mtv-fbc](https://github.com/kubev2v/mtv-fbc) catalog for the Forklift/MTV operator over gRPC using
[`opm`](https://github.com/operator-framework/operator-registry), so that OpenShift, OKD, or any cluster running the
Operator Lifecycle Manager can install and manage the operator through a `CatalogSource`.

For more details, visit https://github.com/kubev2v/forklift and https://github.com/kubev2v/mtv-fbc.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Konveyor is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Red Hat® and Migration Toolkit for Virtualization™ are trademarks of Red Hat, Inc., registered in the United States and
other countries. All rights in these marks are reserved to Red Hat, Inc. Any use by Docker is for referential purposes
only and does not indicate sponsorship, endorsement, or affiliation.

OpenShift® is a registered trademark of Red Hat, Inc. All rights in the mark are reserved to Red Hat, Inc. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

KubeVirt is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
