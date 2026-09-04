## About Forklift Console Plugin

The Forklift console plugin is the web UI of Forklift, the Migration Toolkit for Virtualization maintained by the
kubev2v community. It plugs into the OpenShift web console as a dynamic plugin and adds the migration user interface:
providers, migration plans, and network and storage mappings for moving virtual machines from VMware vSphere, oVirt,
OpenStack, and OVA archives to KubeVirt.

The image serves the compiled plugin bundle (`plugin-manifest.json` plus webpack module chunks) with nginx on port 8080.
A console host loads the bundle at runtime; the Forklift operator deploys this image and registers the plugin with the
console.

For more details, see https://github.com/kubev2v/forklift-console-plugin.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

OpenShift and Red Hat are registered trademarks of Red Hat, Inc. VMware and vSphere are registered trademarks of
Broadcom Inc. OpenStack is a registered trademark of the OpenInfra Foundation. KubeVirt is a trademark of The Linux
Foundation. oVirt is a trademark of Red Hat, Inc. Forklift is an open source project of the kubev2v community. All
rights in those marks are reserved to their respective owners. Any use by Docker is for referential purposes only and
does not indicate sponsorship, endorsement, or affiliation.
