## About Jenkins Agent

Jenkins Agent is a base Docker image that includes Java and the Jenkins agent executable (agent.jar). This executable is
an instance of the Jenkins Remoting library, which enables distributed build capabilities for Jenkins controllers. The
agent connects to a Jenkins controller and executes build tasks, tests, and deployments as part of continuous
integration and continuous deployment (CI/CD) workflows.

As a Docker Hardened Image, this Jenkins Agent container provides a secure, production-ready foundation for your
distributed Jenkins infrastructure. It includes hardened security configurations, minimal CVE exposure, and comes with
complete provenance and Software Bill of Materials (SBOM) metadata for supply chain security.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Jenkins® is a registered trademark of LF Subprojects, LLC. All rights in the mark are reserved to LF Subprojects, LLC.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
