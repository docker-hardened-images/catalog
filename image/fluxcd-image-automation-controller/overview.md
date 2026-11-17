## About Image Automation Controller

The Flux CD Image Automation Controller is a Kubernetes controller that automates container image updates in Git
repositories. It works alongside the image-reflector-controller: when new image tags are detected and an ImagePolicy
selects a new tag, the image-automation-controller commits the updated image reference back to the Git repository,
closing the GitOps loop for image updates.

For more details, see https://fluxcd.io/flux/components/image/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Flux is a trademark of the Cloud Native Computing Foundation. All rights in the mark are reserved to the CNCF. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
