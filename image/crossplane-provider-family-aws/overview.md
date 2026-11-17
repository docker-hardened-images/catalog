## About Crossplane Provider Family AWS

The Crossplane provider for Amazon Web Services (AWS) lets Crossplane manage AWS resources as Kubernetes objects. It is
split into a family of provider packages. The family provider in this image carries the AWS `ProviderConfig`,
`ClusterProviderConfig`, and `ProviderConfigUsage` APIs. The AWS service providers of the same family, for example the
providers for S3, IAM, and RDS, share these APIs to find their AWS credentials. The service providers are separate
packages and are not in this image.

For more details, visit https://github.com/crossplane-contrib/provider-upjet-aws.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Crossplane® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Amazon Web Services and AWS are trademarks of Amazon.com, Inc. or its affiliates. All rights in the marks are reserved
to Amazon.com, Inc. or its affiliates. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation.
