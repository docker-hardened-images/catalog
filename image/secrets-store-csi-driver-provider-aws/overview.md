## About AWS Provider for Secrets Store CSI Driver

`secrets-store-csi-driver-provider-aws` is the official AWS provider plugin for the Kubernetes
[Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/). It lets Kubernetes pods mount secrets from
AWS Secrets Manager and AWS Systems Manager Parameter Store directly as files, without embedding credentials or secret
values in application code or container images.

The provider runs as a DaemonSet alongside the Secrets Store CSI Driver, authenticating to AWS through IAM Roles for
Service Accounts (IRSA) or EKS Pod Identity, and supports cross-account secret access, automated failover regions, and
JMESPath filtering of JSON secrets.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
