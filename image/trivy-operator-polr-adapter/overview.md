## About the Trivy Operator Polr Adapter

Trivy Operator continuously scans Kubernetes workloads and produces custom resources such as `VulnerabilityReport` and
`ConfigAuditReport`. These CRDs are specific to Trivy Operator and aren't directly consumable by generic
policy-reporting tooling.

The Trivy Operator Polr Adapter watches these Trivy Operator CRDs and maps them into the vendor-neutral
`PolicyReport` and `ClusterPolicyReport` resources defined by the Kubernetes Policy Working Group (and the OpenReports
API). This makes Trivy Operator's findings consumable by tooling built around that shared standard, such as
[Policy Reporter](https://github.com/kyverno/policy-reporter) and its Trivy plugin.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software
Bill of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting
seamlessly into existing Docker workflows.

## Attribution

The Trivy Operator Polr Adapter is an open source project authored and maintained by
[Frank Jogeleit](https://github.com/fjogeleit), distributed under the MIT License. This image packages the
upstream project; it is not affiliated with or endorsed by the original author beyond redistribution under the terms
of that license.
