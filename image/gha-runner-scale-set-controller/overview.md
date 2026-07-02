## About Actions Runner Controller

Actions Runner Controller (ARC) is a Kubernetes operator that orchestrates and scales self-hosted runners for GitHub
Actions. It watches `AutoscalingRunnerSet` custom resources and automatically scales runner pods up and down based on
the number of queued workflow jobs in a repository, organization, or enterprise. Runners are ephemeral and
container-based, so new instances start and stop rapidly without leaving residual state.

ARC is installed via Helm charts and requires a GitHub App or personal access token to authenticate to the GitHub API.
The controller manages the full lifecycle of runner scale sets and spawns a per-scale-set listener process
(`ghalistener`) that polls GitHub for pending jobs. Optional components (`github-webhook-server`,
`actions-metrics-server`) enable webhook-driven scaling and Prometheus metrics respectively.

For more details, see https://github.com/actions/actions-runner-controller.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

GitHub® and GitHub Actions™ are trademarks of GitHub, Inc., a subsidiary of Microsoft Corporation. All rights in those
marks are reserved to GitHub, Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
