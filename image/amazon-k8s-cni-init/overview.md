## About amazon-vpc-cni-k8s (init container)

Init container for the Amazon VPC CNI plugin. It runs once per node to copy CNI binaries and supporting artifacts into
the host CNI directory and perform the node-level setup the main `aws-node` container relies on.

Use this image as the `aws-vpc-cni-init` init container alongside the Docker Hardened `amazon-k8s-cni` image in the same
DaemonSet, following upstream Amazon VPC CNI manifests or Helm values.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Amazon Web Services, AWS, and Amazon EFS are trademarks or registered trademarks of Amazon.com, Inc. or its affiliates.
All rights in the marks are reserved to Amazon.com, Inc. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.
