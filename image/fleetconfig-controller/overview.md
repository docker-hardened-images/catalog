## About FleetConfig Controller

FleetConfig Controller declaratively manages Open Cluster Management hub and spoke lifecycle resources so you can
bootstrap, join, upgrade, and remove OCM components through Kubernetes APIs instead of imperative command sequences.

This hardened image is intended to run inside Kubernetes, preserves the upstream `/manager` entrypoint behavior, and
also bundles `clusteradm` for operational OCM workflows. For more details, visit
https://github.com/open-cluster-management-io/lab/tree/main/fleetconfig-controller.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
