## About Calico Node Driver Registrar

Calico Node Driver Registrar is a sidecar container that registers the Calico CSI driver with the kubelet using the
kubelet plugin registration mechanism. The Tigera Operator deploys it alongside the Calico CSI driver on Calico node
pods.

For complete documentation, architecture details, and deployment guides, see the official Calico documentation at
https://docs.tigera.io/calico.

### How Calico packages the upstream registrar

Calico does not maintain a separate node-driver-registrar application. The image published as
`calico/node-driver-registrar` is a **repackaging** of the upstream
[kubernetes-csi/node-driver-registrar](https://github.com/kubernetes-csi/node-driver-registrar) project.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Calico® is a trademark of Tigera, Inc. All rights in the mark are reserved to Tigera, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
