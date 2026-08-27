## About Calico Whisker

Calico Whisker is the web UI for viewing network flows in Calico-managed Kubernetes clusters. It is served by nginx and
ships the React application built from the Project Calico monorepo (`whisker/`). The Tigera Operator deploys this image
when the Whisker component is enabled.

Whisker is the **UI container only**. Calico also publishes a separate `calico/whisker-backend` image that provides the
API the UI proxies to at `/whisker-backend/`. Both components are required for a full Whisker deployment in Kubernetes.

Key responsibilities of Calico Whisker:

- **Flow visualization UI**: Presents Calico network flow data in a browser-based interface
- **Static asset delivery**: Serves the built React application over HTTP
- **Runtime configuration**: Exposes cluster metadata via `/config/config.json`, generated from environment variables at
  startup
- **Backend proxying**: Forwards `/whisker-backend/` requests to the Whisker backend service in the cluster

This Docker Hardened Image ships the Whisker static UI and nginx on a minimal static base, matching upstream
`calico/whisker` entrypoint and port behavior.

For more information, see https://docs.tigera.io/calico/latest/whisker/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Calico® is a trademark of Tigera, Inc. All rights in the mark are reserved to Tigera, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
