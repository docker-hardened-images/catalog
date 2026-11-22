## About AWS Controllers for Kubernetes EventBridge Controller

The AWS Controllers for Kubernetes (ACK) EventBridge controller is the ACK service controller for Amazon EventBridge. It
runs in a Kubernetes cluster and reconciles EventBridge event buses, rules, archives, and endpoints, which are defined
as `eventbridge.services.k8s.aws` custom resources, with AWS. Use it to manage event routing declaratively from
Kubernetes manifests and GitOps tooling.

For more information, see the [ACK documentation](https://aws-controllers-k8s.github.io/community/) and the
[eventbridge-controller repository](https://github.com/aws-controllers-k8s/eventbridge-controller).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Amazon Web Services, AWS, Amazon EventBridge, and EventBridge are trademarks of Amazon.com, Inc. or its affiliates.
Kubernetes® is a registered trademark of The Linux Foundation. All rights in these marks are reserved to their
respective owners. This image packages the open-source AWS Controllers for Kubernetes (ACK) EventBridge controller, an
independent project. Any use by Docker is for referential purposes only, to describe compatibility, and does not
indicate sponsorship, endorsement, or affiliation.
