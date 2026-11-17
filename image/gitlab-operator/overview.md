## About GitLab Operator

GitLab Operator is a Kubernetes operator that deploys and manages GitLab instances on Kubernetes and OpenShift. It
watches `GitLab` custom resources (`apps.gitlab.com/v1beta1`) and reconciles them by deploying the GitLab Helm chart
that is bundled in the image, so a single resource describes a complete GitLab installation.

Each GitLab Operator release line deploys a matching GitLab release: operator 3.3.x deploys GitLab 19.3.x, operator
3.4.x deploys GitLab 19.4.x and operator 3.5.x deploys GitLab 19.5.x. Use the operator line that matches the GitLab
version you run.

For more information, visit the [GitLab Operator documentation](https://docs.gitlab.com/operator/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

GitLab is a trademark of GitLab Inc. in the United States and other countries and regions. All rights in the mark are
reserved to GitLab Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
