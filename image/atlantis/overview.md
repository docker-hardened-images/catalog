## About Atlantis

Atlantis is a self-hosted Go application that automates Terraform pull request workflows. It listens for webhook events
from your VCS provider (GitHub, GitLab, Gitea, Azure DevOps, or Bitbucket), runs `terraform plan` and `terraform apply`
on the affected directories, and comments the output back on the pull request.

Teams use Atlantis to make infrastructure changes visible for review, let non-operations engineers collaborate on
Terraform safely, and standardize Terraform workflows across repositories without granting every contributor direct
access to Terraform state or credentials.

For more details, visit https://www.runatlantis.io.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Atlantis is a trademark of the Atlantis project maintainers (runatlantis). Any use by Docker is for referential purposes
only and does not indicate sponsorship, endorsement, or affiliation.
