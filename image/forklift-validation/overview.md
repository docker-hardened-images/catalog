## About Forklift Validation

Forklift Validation is the policy enforcement component of the [Forklift](https://github.com/kubev2v/forklift) VM
migration operator for KubeVirt. It runs an [Open Policy Agent](https://www.openpolicyagent.org/) (OPA) server loaded
with Rego validation policies that the Forklift controller consults before and during virtual machine migrations.

The service evaluates source VMs against a set of provider-specific Rego policies before and during migration. Policies
are organized by source provider:

- **VMware** — disk mode, snapshots, CBT, DRS/DPM, CPU/NUMA affinity, RDM disks, SR-IOV, TPM, USB, OS type, and more
- **oVirt** — CPU policy/tune/shares, disk interface type, NIC configuration, HA, IO threads, placement policy, TPM, and
  more
- **OpenStack** — disk size/status/interface, NIC VIF models, floating IPs, host devices, NUMA, secure boot, and more
- **Hyper-V** — integration services, secure boot, TPM, checkpoint, disk SMB path, OS type, and more
- **OVA** — CPU affinity, CPU/memory hotplug, disk size, export source

The OPA server exposes a REST API on port `8181/tcp`. The Forklift controller posts VM inventory data as OPA input and
receives structured concern lists in return.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

OPEN POLICY AGENT is a trademark of The Linux Foundation. Use of this trademark does not imply endorsement by The Linux
Foundation or the Open Policy Agent project.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
