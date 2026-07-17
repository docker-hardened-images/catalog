## About Yet Another CloudWatch Exporter (YACE)

Yet Another CloudWatch Exporter (YACE) is a Prometheus exporter for AWS CloudWatch metrics, written in Go using the
official AWS SDK. It automatically discovers AWS resources via tags across more than 100 supported services — including
EC2, RDS, Lambda, ELB, and many more — and exposes their CloudWatch metrics as Prometheus metrics with AWS resource tags
and CloudWatch dimensions added as labels. YACE supports cross-account scraping via IAM role assumption and can pull
static metrics for namespaces that do not support tag-based auto-discovery.

YACE joined the [Prometheus community](https://github.com/prometheus-community) organization in November 2024. For full
configuration reference and installation guides, see the
[upstream project documentation](https://github.com/prometheus-community/yet-another-cloudwatch-exporter).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Prometheus® and Kubernetes® are registered trademarks of The Linux Foundation. All rights in these marks are reserved to
The Linux Foundation. Amazon Web Services, AWS, and the AWS logo are trademarks of Amazon.com, Inc. or its affiliates.
All rights in these marks are reserved to their respective owners. Any use by Docker is for referential purposes only
and does not indicate sponsorship, endorsement, or affiliation.
