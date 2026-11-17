## About Forklift Controller

Forklift Controller is the orchestration component of the [Forklift](https://github.com/kubev2v/forklift) VM migration
operator for KubeVirt. It reconciles the Forklift custom resources — providers, plans, mappings, hooks, and migrations —
and drives each virtual machine migration from inventory discovery through disk transfer to a running KubeVirt VM.

The controller migrates virtual machines from VMware vSphere, oVirt, OpenStack, Hyper-V, EC2, and OVA sources. It
coordinates the supporting components of a migration: it consults the Forklift validation service for policy concerns,
creates the data volumes and populators that copy disks, and invokes virt-v2v for guest conversion so that migrated
guests boot with the correct drivers. It also supports warm migration using changed block tracking, and can migrate to
remote clusters.

The controller serves its inventory API on port `8080/tcp` and Prometheus metrics on port `2112/tcp`. As upstream, its
manager metrics endpoint also defaults to port `8080`, so deployments set `API_PORT` and `METRICS_PORT` explicitly.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Konveyor is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

KubeVirt is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
