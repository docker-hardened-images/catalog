## About Portieris

Portieris is a Kubernetes admission controller that enforces image security policies. It runs as a mutating admission
webhook: for each image in a workload it finds the matching ImagePolicy or ClusterImagePolicy, and it prevents the
workload from deploying when any image does not satisfy that policy.

Policies can allow images by repository pattern, require Docker Content Trust signatures from a Notary server, or
require Red Hat simple signing signatures verified against a public key. When a policy verifies a signature, Portieris
rewrites the image reference to its digest so that the admitted image is the one that is pulled.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation in the United States and other countries. Docker's use is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
