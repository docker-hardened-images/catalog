## About Centrifugo

Centrifugo is an open-source scalable real-time messaging server. It lets an application backend expose WebSocket, SSE,
and HTTP-streaming publish/subscribe endpoints without embedding a message broker into the backend itself. Clients
connect and receive messages published to channels; publishing is done from the backend over a language-agnostic HTTP or
GRPC server API.

This hardened image is built from the official [centrifugal/centrifugo](https://github.com/centrifugal/centrifugo)
source and is intended to run as a standalone real-time messaging server, either directly or fronted by a proxy.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Centrifugo and the Centrifugo logo are trademarks of Centrifugal Labs LTD. Any use by Docker is for referential purposes
only and does not indicate sponsorship, endorsement, or affiliation.
