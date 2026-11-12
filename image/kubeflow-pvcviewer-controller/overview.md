## About Kubeflow PVCViewer Controller

The Kubeflow PVCViewer Controller is a Kubernetes operator that starts a file browser for a PersistentVolumeClaim. You
create a `PVCViewer` resource for a claim, and the controller runs a viewer Deployment for it, with a Service and an
Istio VirtualService when you set `spec.networking`. The controller also serves the admission webhooks for `PVCViewer`
resources. It is upstream's `pvcviewer-controller` from the
[Kubeflow Notebooks project](https://github.com/kubeflow/notebooks/tree/notebooks-v1/components/pvcviewer-controller).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

KubeFlow® is a registered trademark of The Linux Foundation in the United States and/or other countries. Docker's use is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
