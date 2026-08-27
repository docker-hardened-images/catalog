## About Notification Controller

The Flux CD Notification Controller is a Kubernetes controller that handles event-based notifications and webhook
receivers. It dispatches Flux reconciliation events to external systems such as Slack, GitHub, GitLab, PagerDuty,
Microsoft Teams, and many other providers. It also exposes a webhook receiver endpoint that allows external systems to
trigger Flux reconciliation on demand.

For more details, see https://fluxcd.io/flux/components/notification/.

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
