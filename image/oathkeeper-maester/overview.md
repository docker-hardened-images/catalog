## About Ory Oathkeeper Maester

Ory Oathkeeper Maester is a Kubernetes controller for Ory Oathkeeper access rules. It watches `Rule` custom resources in
the `oathkeeper.ory.sh/v1alpha1` API group, validates the handlers they reference, and renders every valid rule into the
JSON access rules document that Oathkeeper reads, so access rules are managed as Kubernetes objects instead of a
hand-edited file.

It runs in one of two modes: as a standalone controller Deployment that writes the rules into a ConfigMap mounted by
Oathkeeper, or as a sidecar container next to Oathkeeper that writes the rules to a shared file. Maester is developed by
the Ory community and is not actively maintained by the Ory core maintainers.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Ory and Ory Oathkeeper are trademarks of Ory Corp. Kubernetes®
is a registered trademark of The Linux Foundation. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
