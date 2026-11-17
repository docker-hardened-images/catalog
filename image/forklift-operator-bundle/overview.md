## About Forklift Operator Bundle

Forklift is the upstream project behind Red Hat Migration Toolkit for Virtualization (MTV), part of the
[Konveyor](https://konveyor.io/) community. It migrates virtual machines at scale to Kubernetes KubeVirt/OpenShift
Virtualization from source providers such as VMware vSphere, oVirt, OpenStack, and OVA, using a choreographed plan of
credentials, infrastructure mapping, and execution steps.

This image is an [OLM](https://olm.operatorframework.io/) operator bundle: it carries the Forklift operator's Kubernetes
manifests (`ClusterServiceVersion`, CRDs and a `ClusterRole`) under `/manifests` and OLM metadata under `/metadata`,
ships no entrypoint or binaries of its own, and is unpacked by the Operator Lifecycle Manager through a copy helper it
injects. The manifests are generated from the upstream source with `kustomize` and `operator-sdk generate bundle`, with
every component image reference pointing at its Docker Hardened Images counterpart.

For more details, visit https://github.com/kubev2v/forklift.

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

Red Hat® and Migration Toolkit for Virtualization™ are trademarks of Red Hat, Inc., registered in the United States and
other countries. All rights in these marks are reserved to Red Hat, Inc. Any use by Docker is for referential purposes
only and does not indicate sponsorship, endorsement, or affiliation.

OpenShift® is a registered trademark of Red Hat, Inc. All rights in the mark are reserved to Red Hat, Inc. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

KubeVirt is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
