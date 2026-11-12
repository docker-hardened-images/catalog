## About GitHub Actions Runner

The GitHub Actions runner is the agent that listens for and executes workflow jobs dispatched from a GitHub repository
or organization to self-hosted infrastructure. It registers with GitHub, polls for queued jobs, and runs the steps
defined in a workflow, reporting logs and results back to GitHub.

This image packages the official upstream runner release for use as a self-hosted runner, including in Kubernetes
deployments managed by the Actions Runner Controller.

Source: [https://github.com/actions/runner](https://github.com/actions/runner)

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

GitHub and GitHub Actions are trademarks of GitHub, Inc. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.
