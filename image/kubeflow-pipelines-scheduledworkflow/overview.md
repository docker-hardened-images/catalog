## About Kubeflow Pipelines Scheduled Workflow Controller

The Kubeflow Pipelines Scheduled Workflow Controller is a Kubernetes controller that watches `ScheduledWorkflow` custom
resources (`scheduledworkflows.kubeflow.org`) and starts Argo Workflows for them on a cron or periodic schedule. It is
the component behind recurring runs in [Kubeflow Pipelines](https://www.kubeflow.org/docs/components/pipelines/), and
runs alongside the Kubeflow Pipelines API server. This image packages the controller from the upstream
[kubeflow/pipelines](https://github.com/kubeflow/pipelines) project, in its 2.17 and 2.18 releases (2.17.3 and 2.18.1),
as a Docker Hardened Image. It ships runtime, dev, and FIPS variants.

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
