## About this Helm chart

This is a Ztunnel Docker Hardened Helm chart built from the upstream Istio Ztunnel Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/ztunnel`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://istio.io/latest/docs/ambient/](https://istio.io/latest/docs/ambient/)

### About ZTunnel

Ztunnel is intended to be a purpose built implementation of the node proxy in ambient mesh. Part of the goals of this
included keeping a narrow feature set, implementing only the bare minimum requirements for ambient. This ensures the
project remains simple and high performance.

For more details, visit https://istio.io/latest/blog/2022/introducing-ambient-mesh/.

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
