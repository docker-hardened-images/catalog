## About stunnel

stunnel is a TLS encryption proxy that adds SSL/TLS protection to network connections made by programs that have no
built-in TLS support. It sits between a client and a server, terminating or originating TLS on one side and passing
plaintext traffic on the other, so that legacy services can participate in encrypted communication without any
modification to their source code.

Common use cases include wrapping plaintext SMTP, IMAP, LDAP, and PostgreSQL connections with TLS, offloading TLS
termination from backend services that cannot handle certificates directly, and creating authenticated TLS tunnels
between two hosts. stunnel operates in either client mode (connecting to a remote TLS endpoint) or server mode
(accepting TLS connections and forwarding plaintext to a local service), and a single process can run multiple named
service sections simultaneously.

For more information, visit the [stunnel project website](https://www.stunnel.org/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

OpenSSL is a trademark of the OpenSSL Software Foundation. Any use by Docker is for referential purposes only and does
not indicate sponsorship, endorsement, or affiliation.

All other third-party product names, logos, and brands referenced are the property of their respective owners. Use here
is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation by Docker.
