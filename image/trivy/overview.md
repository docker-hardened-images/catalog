## About Trivy

Trivy is a comprehensive and versatile security scanner for containerized applications and infrastructure. It provides
multiple scanners that detect vulnerabilities, misconfigurations, secrets, and SBOM (Software Bill of Materials) across
various targets including container images, filesystems, Git repositories, Kubernetes clusters, and cloud
infrastructure.

Trivy excels at finding security issues in:

- **Container images**: Scans OS packages and application dependencies for known vulnerabilities
- **Infrastructure as Code (IaC)**: Detects misconfigurations in Terraform, CloudFormation, Kubernetes manifests, and
  more
- **Secrets**: Identifies hardcoded secrets, API keys, and credentials in code and configuration files
- **Kubernetes**: Scans clusters for security issues and compliance violations
- **SBOM**: Generates and analyzes Software Bills of Materials
- **License compliance**: Checks for license violations in dependencies

Key features include:

- Fast and accurate vulnerability scanning with multiple vulnerability databases
- Support for multiple languages and frameworks (Go, Node.js, Python, Java, .NET, etc.)
- Built-in policies for security best practices and compliance standards
- Integration with CI/CD pipelines and security tools
- Detailed reporting in multiple formats (JSON, SARIF, table, etc.)

For more details, visit https://aquasecurity.github.io/trivy/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Trivy® is a trademark of Aqua Security Software Ltd. All rights in the mark are reserved to Aqua Security Software Ltd.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
