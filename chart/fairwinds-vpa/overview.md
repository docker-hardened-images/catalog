## About this Helm chart

A Helm chart to install Kubernetes Vertical Pod Autoscaler that suits Fairwinds suit of products. This is built from the
upstream Fairwinds VPA Helm chart using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/kubectl`
- `dhi/kube-webhook-certgen`
- `dhi/vpa-admission-controller`
- `dhi/vpa-recommender`
- `dhi/vpa-updater`

The following Docker Hardened Helm charts are used in this Helm chart:

- `dhi/metrics-server-chart`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/FairwindsOps/charts/tree/master/stable/vpa/README.md](https://github.com/FairwindsOps/charts/tree/master/stable/vpa/README.md)

## About Fairwinds Vertical Pod Autoscaler

Vertical Pod Autoscaler (VPA) frees users from the necessity of setting up-to-date resource requests for the containers
in their pods. When configured, it will set the requests automatically based on usage and thus allow proper scheduling
onto nodes so that appropriate resource overhead is available for each pod. It will also maintain ratios between
requests and limits that were specified in initial containers configuration.

It can both down-scale pods that are over-requesting resources, and also up-scale pods that are under-requesting
resources based on their usage over time.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
