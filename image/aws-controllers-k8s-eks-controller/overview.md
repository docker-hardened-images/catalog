## About ACK EKS Controller

The AWS Controllers for Kubernetes (ACK) EKS controller is a Kubernetes operator that manages Amazon EKS resources as
Kubernetes custom resources. It reconciles the custom resources in the `eks.services.k8s.aws/v1alpha1` API group,
including `Cluster`, `Nodegroup`, `FargateProfile`, `Addon`, `AccessEntry`, `IdentityProviderConfig`,
`PodIdentityAssociation`, and `Capability`, against the Amazon EKS API. The upstream project and its documentation are
at [github.com/aws-controllers-k8s/eks-controller](https://github.com/aws-controllers-k8s/eks-controller).

The image contains the upstream controller binary, `/bin/controller`, on a minimal runtime base. It runs as a nonroot
user and is deployed into a cluster with the upstream Helm chart, which installs the custom resource definitions and the
controller Deployment.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation in the United States and other countries. Amazon Elastic
Kubernetes Service (Amazon EKS) and Amazon Web Services (AWS) are trademarks of Amazon.com, Inc. or its affiliates.
Docker's use is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
