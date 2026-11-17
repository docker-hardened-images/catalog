## About Linstor Affinity Controller

The LINSTOR Affinity Controller keeps Kubernetes PersistentVolume affinity in sync with LINSTOR volume placement. It
automates the recreation of PersistentVolume objects when the backing LINSTOR resource migrates, enabling strict
affinity settings for optimal workload scheduling and local data access. This is particularly useful in environments
with ephemeral infrastructure where nodes are created and discarded on demand.

For more details, visit the
[LINSTOR Affinity Controller GitHub repository](https://github.com/piraeusdatastore/linstor-affinity-controller).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

LINSTOR is a registered trademark of LINBIT. All rights in the mark are reserved to LINBIT. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Piraeus Datastore™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
