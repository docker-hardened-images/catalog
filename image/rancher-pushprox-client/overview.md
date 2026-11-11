## About Rancher PushProx Client

Rancher PushProx Client is the `pushprox-client` binary from the [PushProx](https://github.com/rancher/PushProx)
project. It runs next to Prometheus targets that cannot be scraped directly, such as hosts behind NAT or a firewall. The
client registers with a PushProx proxy and serves Prometheus scrapes that the proxy relays to it. Use it as a sidecar or
DaemonSet alongside the target, or as the `rancher-pushprox` chart's client component.

This image is a drop-in for `rancher/pushprox-client`. It keeps the upstream entrypoint and command so
`pushprox-client --proxy-url=…` works as before. It runs as a non-root user and listens for metrics on port 9369.

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
