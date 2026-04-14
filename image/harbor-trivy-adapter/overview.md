## About Harbor Trivy Adapter

Harbor Trivy Adapter is a scanner adapter that wraps the Trivy vulnerability scanner to provide integration with Harbor
registry. It exposes a REST API that Harbor uses to scan container images for vulnerabilities, misconfigurations, and
secrets using Trivy.

The adapter acts as a bridge between Harbor's scanner API and the Trivy CLI, enabling Harbor to leverage Trivy's
vulnerability detection across OS packages, application dependencies, and known CVEs.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Harbor® is a registered trademark of the Linux Foundation®. Trivy™ is a trademark of Aqua Security Software Ltd. This
listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their respective
owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
