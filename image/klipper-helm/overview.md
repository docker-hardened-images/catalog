## About Klipper Helm

Klipper Helm is the container image that runs Helm install, upgrade, and uninstall operations on behalf of the Helm
controller embedded in [K3s](https://k3s.io/) and [RKE2](https://docs.rke2.io/). It ships the upstream `entry` script,
Helm 3, and the `helm-set-status` and `helm-mapkubeapis` plugins used by that controller.

This Docker Hardened Image follows the same entrypoint and environment contract as the upstream job image so it can be
used as a drop-in replacement when you want a minimal, non-root runtime with an SBOM and supply-chain hardening.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

K3s is a CNCF Sandbox project. RKE2 is associated with SUSE Rancher. This listing is prepared by Docker. All third-party
product names, logos, and trademarks are the property of their respective owners and are used solely for identification.
Docker claims no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
