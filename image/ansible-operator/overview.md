## About Ansible Operator

Ansible Operator is the runtime base image of the [Operator SDK](https://sdk.operatorframework.io/) for building
Kubernetes operators in Ansible. It bundles the `ansible-operator` controller, which watches custom resources and runs
the Ansible roles or playbooks declared in `watches.yaml`, together with the Ansible runtime it drives: `ansible-core`,
`ansible-runner` and the Kubernetes Python client.

Operators built on this image add their own roles, playbooks, collections and `watches.yaml` on top of it with a short
Dockerfile, the way the Operator SDK scaffolds them.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Operator Framework is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Ansible® is a registered trademark of Red Hat, Inc. All rights in the mark are reserved to Red Hat. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
