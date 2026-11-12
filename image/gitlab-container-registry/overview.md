## About GitLab Container Registry

The GitLab Container Registry is a registry server for storing, managing, and distributing OCI and Docker container
images and artifacts. Originally a fork of the CNCF Distribution project, it has diverged significantly to add
GitLab-specific capabilities, most notably a relational metadata database and online garbage collection.

It powers the container registry integrated into GitLab and is distributed as part of GitLab's Cloud Native (CNG)
component set. It supports multiple storage backends, including the local filesystem and S3, Azure, and Google Cloud
object storage.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

GitLab® is a registered trademark of GitLab Inc. All rights in the mark are reserved to GitLab Inc. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
