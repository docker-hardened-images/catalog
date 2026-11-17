## About Logging operator

Logging operator is a Kubernetes operator that automates the deployment and configuration of a logging pipeline. It
deploys a Fluent Bit agent on every node and a Fluentd or syslog-ng log forwarder, and renders their configuration from
`Logging`, `Flow` and `Output` custom resources.

It is a CNCF Sandbox project written in Go. This image is the operator itself; the Fluentd, Fluent Bit, syslog-ng and
sidecar images it deploys are separate images selected in the `Logging` resource.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Logging Operator™ is a trademark of The Linux Foundation, and Kubernetes® is a registered trademark of The Linux
Foundation. All rights in the marks are reserved to The Linux Foundation. Any use by Docker is for referential purposes
only and does not indicate sponsorship, endorsement, or affiliation.
