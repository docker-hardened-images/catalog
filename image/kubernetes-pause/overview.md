## About Kubernetes pause

The Docker Hardened `kubernetes-pause` image packages the minimal Kubernetes `pause` infrastructure container used to
hold a pod's shared namespaces open. It intentionally does very little beyond remaining alive, handling signals as PID
1, and providing a small `-v` flag for version output.

For more details, visit
[the upstream Kubernetes source tree](https://github.com/kubernetes/kubernetes/tree/master/build/pause).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
