## About Cilium Hubble Export to Stdout

Hubble Export to Stdout is a minimal utility image within the Cilium observability ecosystem. Its sole purpose is to
tail one or more Hubble flow-log export files and stream their contents to stdout, making them available to a sidecar
log collector such as Fluentd or Fluent Bit. The image contains only busybox (providing `sh` and `tail`) and a small
shell script, keeping the footprint as small as possible.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Cilium® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
