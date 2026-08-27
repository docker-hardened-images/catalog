## About this Helm chart

This is a Karpenter Docker Hardened Helm chart built from the upstream Karpenter Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/karpenter`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://karpenter.sh/docs/](https://karpenter.sh/docs/)

## About Karpenter

Karpenter is an open-source Kubernetes node autoscaler built for flexibility, performance, and simplicity. It improves
the efficiency and cost of running workloads on Kubernetes clusters by:

- Watching for pods that the Kubernetes scheduler has marked as unschedulable
- Evaluating scheduling constraints (resource requests, nodeselectors, affinities, tolerations, and topology spread
  constraints) requested by the pods
- Provisioning nodes that meet the requirements of the pods
- Removing the nodes when the nodes are no longer needed

Karpenter was originally developed by AWS and is designed to work seamlessly with Amazon EKS, though it can be adapted
for other Kubernetes environments.

Official documentation: https://karpenter.sh/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a trademark of the Linux Foundation. Karpenter is a trademark of Amazon Web Services, Inc. All rights in
the marks are reserved to their respective owners. All third-party product names, logos, and trademarks are the property
of their respective owners and are used solely for identification. Docker claims no interest in those marks, and no
affiliation, sponsorship, or endorsement is implied.
