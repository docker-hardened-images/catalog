## About Amazon EKS Pod Identity Webhook

The Amazon EKS Pod Identity Webhook is a Kubernetes mutating admission webhook that implements IAM Roles for Service
Accounts (IRSA). It watches for pods whose service account is annotated with an IAM role ARN and injects the
`AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE` environment variables, along with a projected service account token
volume, so AWS SDKs inside the pod can assume that role without long-lived credentials.

It typically runs as a Deployment inside the cluster and is registered with the Kubernetes API server via a
`MutatingWebhookConfiguration`, which calls the webhook's `/mutate` endpoint for every pod creation.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. Amazon Web Services, AWS, EKS, and the AWS logo are
trademarks of Amazon.com, Inc. or its affiliates. All rights in these marks are reserved to their respective owners. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
