## About Rancher PushProx

Rancher PushProx is a proxy and client that let Prometheus scrape targets behind NAT or firewalls while keeping the pull
model. A client runs beside each target and polls the proxy for scrape requests, and Prometheus scrapes the proxy, which
relays each request to the right client. The upstream project is
[rancher/PushProx](https://github.com/rancher/PushProx), a fork of `prometheus-community/PushProx`, licensed under
Apache-2.0.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Rancher is a trademark of SUSE. Docker's use of the name is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation with SUSE.

This listing is prepared by Docker. All other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
