## About Forklift Operator

Forklift Operator installs and manages [Forklift](https://github.com/kubev2v/forklift), the VM migration toolkit for
KubeVirt. It is an Ansible-based operator: a single `ForkliftController` custom resource describes the desired Forklift
installation, and the operator reconciles it by deploying and configuring the Forklift components - the controller and
inventory service, the migration API, the validation service, the volume populators, and the OpenShift console plugin.

Forklift migrates virtual machines from VMware vSphere, oVirt, OpenStack, Hyper-V, EC2, and OVA sources to KubeVirt. The
operator is the entry point of a Forklift installation: it owns the lifecycle of every other Forklift component and
exposes feature flags and image references for each of them through the `ForkliftController` resource and its
environment.

The image combines the `ansible-operator` runtime binary from the Operator SDK ansible plugins with the Ansible runtime
(`ansible-core` and `ansible-runner`), the Kubernetes Ansible collections, and the Forklift operator role. It serves
health probes on port `6789/tcp` and metrics on port `8443/tcp`.

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

Ansible® is a registered trademark of Red Hat, Inc. All rights in the mark are reserved to Red Hat. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
