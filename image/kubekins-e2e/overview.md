## About kubekins-e2e

kubekins-e2e is the image the Kubernetes project's Prow CI uses to run end-to-end test jobs. Its entrypoint,
`runner.sh`, wraps the job's command, and the image carries the tools those jobs call: kubetest2 with its deployers and
testers, kind, kubectl, Docker Engine for Docker-in-Docker, the Go toolchain, the Google Cloud CLI, the AWS CLI, helm
and the GitHub CLI. Charts such as the AWS EBS CSI driver also use it for their Helm test pod.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. Any use by Docker is for referential purposes only and
does not indicate sponsorship, endorsement, or affiliation.
