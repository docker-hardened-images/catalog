## About ktls-utils

ktls-utils provides a TLS handshake user agent (tlshd) that services TLS handshake requests on behalf of kernel TLS
consumers. In-kernel TLS consumers need a mechanism to perform TLS handshakes on connected sockets to negotiate TLS
session parameters that can then be programmed into the kernel's TLS record protocol engine.

This package materializes kernel socket endpoints in user space to perform TLS handshakes using the GnuTLS library.
After each handshake completes, tlshd plants negotiated session parameters back into the kernel via standard kTLS socket
options, enabling the kernel to handle the TLS record protocol for subsequent communication.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

ktls-utils is a trademark of Oracle Cooporation. All rights in the mark are reserved to Oracle Cooporation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
