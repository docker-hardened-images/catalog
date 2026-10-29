## About the Trivy Policy Reporter Plugin

Trivy is a comprehensive security scanner from Aqua Security that detects vulnerabilities, misconfigurations, and
secrets across containers, filesystems, and Kubernetes clusters. In a cluster, Trivy Operator continuously scans
workloads and produces `VulnerabilityReports`, which the Trivy Operator Polr Adapter converts into `PolicyReports`.

The Trivy Policy Reporter Plugin extends the Policy Reporter UI with Trivy-specific views. It takes those
`PolicyReports` and enriches each finding with detailed vulnerability metadata — descriptions, affected and fixed
versions, and references — pulled from the CVE program and GitHub Security Advisories.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software
Bill of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting
seamlessly into existing Docker workflows.

## Trademarks

Trivy® is a trademark of Aqua Security Software Ltd. All rights in the mark are reserved to Aqua Security Software
Ltd. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
