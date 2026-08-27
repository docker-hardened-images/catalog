## About AWS Load Balancer Controller

The AWS Load Balancer Controller is a Kubernetes controller that manages AWS Elastic Load Balancers for Kubernetes
clusters. It provisions Application Load Balancers (ALBs) for Kubernetes Ingress resources, Network Load Balancers
(NLBs) for Kubernetes Service resources, and supports the Kubernetes Gateway API for both ALB and NLB provisioning.
Formerly known as the AWS ALB Ingress Controller, the project was donated to Kubernetes SIG-AWS in 2018 and is
maintained by AWS as the recommended solution for load balancing on Amazon EKS and self-managed Kubernetes clusters
running on AWS.

For more information, see the
[AWS Load Balancer Controller documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Amazon Web Services, AWS, and the AWS logo are trademarks or registered trademarks of Amazon.com, Inc. or its
affiliates. Kubernetes is a registered trademark of The Linux Foundation. Any use by Docker is for referential purposes
only and does not indicate sponsorship, endorsement, or affiliation.
