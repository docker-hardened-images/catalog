## About Kyverno Policies

Kyverno Policies is a curated library of Kyverno `ClusterPolicy` (and CEL-based `ValidatingPolicy`) resources that
implement the Kubernetes [Pod Security Standards](https://kyverno.io/policies/pod-security) at the `baseline` or
`restricted` level. Installing this chart adds policy custom resources to your cluster that Kyverno evaluates against
incoming workloads, enforcing or auditing security best practices such as disallowing privileged containers, host
namespaces, and unsafe capabilities.

This chart is image-less: it does not deploy any container images or Pods. It requires the [Kyverno](https://kyverno.io)
admission controller and its Custom Resource Definitions (CRDs) to already be installed and running in the cluster,
since Kyverno is the engine that evaluates the policies this chart creates.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kyverno® and Kubernetes® are trademarks of the Linux Foundation. All rights in the marks are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
