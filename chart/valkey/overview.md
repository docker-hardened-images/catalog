## About this Helm chart

This is a Valkey Docker Helm chart built from the upstream Valkey Helm chart implementation using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/valkey`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/valkey-io/valkey-helm](https://github.com/valkey-io/valkey-helm)

### About Valkey

Valkey is an open source, high-performance data structure server designed for key/value workloads. It supports a rich
set of native data structures and offers an extensible plugin system for adding new types and access patterns. Forked
from Redis before its license change, Valkey continues the tradition of in-memory speed and simplicity while maintaining
a commitment to open governance and community-driven development.

For more details, visit https://valkey.io

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
