## About this Helm chart

This is a KEDA Helm chart built from the upstream KEDA Helm chart and using a hardened configuration with Docker
Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/keda`
- `dhi/keda-metrics-apiserver`
- `dhi/keda-admission-webhooks`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/kedacore/charts/tree/main/keda/README.md](https://github.com/kedacore/charts/tree/main/keda/README.md)

## About KEDA

Kubernetes Event-driven Autoscaling (KEDA) is an open-source project that provides event-driven autoscaling for
Kubernetes workloads. It allows you to scale your applications based on the number of events needing to be processed,
rather than just CPU or memory usage.

KEDA works by integrating with various event sources, such as message queues, HTTP triggers, and more. It can
automatically scale your Kubernetes deployments up or down based on the rate of incoming events, ensuring that your
applications can handle varying workloads efficiently.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Keda™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
