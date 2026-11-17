## About Teleport

Teleport is an identity-aware access platform that provides connectivity, authentication, access controls and audit for
infrastructure. It replaces shared credentials with short-lived certificates, adds single sign-on and multi-factor
authentication in front of SSH servers, Kubernetes clusters, databases, Windows desktops and web applications, and
records sessions for replay.

This hardened image is built from the official [gravitational/teleport](https://github.com/gravitational/teleport)
source (Teleport Community Edition, AGPL-3.0) and ships the `teleport` service together with the `tctl`, `tsh` and
`tbot` tools, ready to run the Auth Service, Proxy Service or an agent.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

The word Teleport and the Teleport logos are registered and/or common law trademarks of Gravitational, Inc.
(https://goteleport.com/legal/wtou/). All rights in the marks are reserved to Gravitational, Inc. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
