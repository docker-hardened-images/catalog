## About AWS EKS Pod Identity Agent

The AWS EKS Pod Identity Agent is a Kubernetes node agent that delivers temporary AWS IAM credentials to pods running on
Amazon EKS clusters. It exchanges projected Kubernetes service account tokens for short-lived AWS credentials by calling
the EKS Auth API, then serves those credentials to pods via a local credential proxy.

The agent runs as a DaemonSet on each EKS node and exposes a local HTTP endpoint that the AWS SDKs and CLI inside
workload pods can use to obtain credentials. The Pod Identity association mapping (which IAM role each service account
maps to) is configured in EKS rather than annotated on the service account, which simplifies cross-account access and
removes the need for the OIDC provider configuration required by IRSA.

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
