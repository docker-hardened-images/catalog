## About Grafana PDC Agent

Grafana PDC Agent is the Private Datasource Connect agent from Grafana Labs. It runs on a private network and opens a
reverse SSH tunnel so Grafana Cloud can query data sources hosted on that network. Once that tunnel is up, the agent
serves metrics on port 8090.

See the
[Private Datasource Connect documentation](https://grafana.com/docs/grafana-cloud/observe-and-act/connect-externally-hosted/private-data-source-connect/)
and the [pdc-agent project](https://github.com/grafana/pdc-agent) for stack setup and the full flag reference.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Grafana® PDC Agent is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank,
Inc. dba Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
