### About Cilium Operator AWS

The Cilium Operator AWS is a specialized component of the Cilium networking and security platform designed to integrate
seamlessly with Amazon Web Services infrastructure. It manages AWS-specific operations and resources required for
Cilium's functionality in AWS environments.

This operator handles tasks such as managing AWS Elastic Network Interfaces (ENIs), integrating with AWS VPC networking,
and coordinating IP address management across EC2 instances. It enables Cilium to leverage AWS-native networking
capabilities while providing advanced network security and observability features.

The AWS operator runs as a separate deployment alongside the main Cilium agent, ensuring that cloud-specific operations
are handled efficiently without impacting the core Cilium functionality.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Cilium is a trademark of the Linux Foundation. Amazon Web Services, AWS, and related marks are trademarks of Amazon.com,
Inc. or its affiliates.

The mention of any third-party products, services, or organizations in this documentation is for informational purposes
only and does not constitute an endorsement or recommendation.
