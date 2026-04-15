## About this Helm chart

This is a Kyverno Helm chart built from the upstream Kyverno Helm chart and using a hardened configuration with Docker
Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/kyverno`
- `dhi/kyverno-cli`
- `dhi/kyverno-readiness-checker`
- `dhi/kyverno-init`
- `dhi/kyverno-background-controller`
- `dhi/kyverno-cleanup-controller`
- `dhi/kyverno-reports-controller`

The following Docker Hardened Helm charts are used in this Helm chart:

- `dhi/kyverno-reports-server-chart`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/kyverno/kyverno/blob/main/charts/kyverno/README.md](https://github.com/kyverno/kyverno/blob/main/charts/kyverno/README.md)

## About Kyverno

Kyverno is a Kubernetes-native policy engine that enables platform and security teams to validate, mutate, generate, and
enforce policies using familiar YAML. It integrates with Kubernetes admission controllers and background scans to
automate security, compliance, and operational guardrails.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kyverno® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
