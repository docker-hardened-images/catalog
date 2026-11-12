## About RKE2 Runtime

RKE2, also known as RKE Government, is Rancher's Kubernetes distribution focused on security and compliance. Each RKE2
release pins a runtime image that the `rke2` binary pulls and extracts onto every node: the `/bin` directory carries
containerd, containerd-shim-runc-v2, ctr, runc, crictl, kubelet and kubectl, and the `/charts` directory carries the
HelmChart manifests for the bundled cluster add-ons (CNI, CoreDNS, ingress, metrics server and others).

This image is not a service. Point RKE2 at it with the `runtime-image` option and the binaries and charts are staged
under the RKE2 data directory on the host.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.

RKE2 is associated with SUSE Rancher. This listing is prepared by Docker. All third-party product names, logos, and
trademarks are the property of their respective owners and are used solely for identification. Docker claims no interest
in those marks, and no affiliation, sponsorship, or endorsement is implied.
