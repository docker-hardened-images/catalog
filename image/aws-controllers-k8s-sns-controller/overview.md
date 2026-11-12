## About ACK SNS Controller

The ACK SNS controller is the AWS Controllers for Kubernetes (ACK) service controller for Amazon Simple Notification
Service (SNS). It runs in a Kubernetes cluster and reconciles SNS topics, subscriptions, platform applications, and
platform endpoints, which are defined as `sns.services.k8s.aws` custom resources, with AWS. Use it to manage SNS
resources declaratively from Kubernetes manifests and GitOps tooling.

For more information, see the [ACK documentation](https://aws-controllers-k8s.github.io/community/) and the
[sns-controller repository](https://github.com/aws-controllers-k8s/sns-controller).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Amazon Web Services, AWS, Amazon Simple Notification Service, and Amazon SNS are trademarks of Amazon.com, Inc. or its
affiliates. Kubernetes® is a registered trademark of The Linux Foundation. All rights in these marks are reserved to
their respective owners. This image packages the open-source AWS Controllers for Kubernetes (ACK) SNS controller, an
independent project. Any use by Docker is for referential purposes only, to describe compatibility, and does not
indicate sponsorship, endorsement, or affiliation.
