## About Kubeflow Notebook Controller

The Kubeflow Notebook Controller is a Kubernetes controller that reconciles `kubeflow.org/v1` `Notebook` custom
resources into a StatefulSet and a Service for each notebook server. This image packages the controller from the
upstream [kubeflow/notebooks](https://github.com/kubeflow/notebooks) project, release v1.11.1, as a Docker Hardened
Image. It ships runtime, dev, and FIPS variants.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

KubeFlow® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
