## About Grafana Rollout Operator

[Grafana Rollout Operator](https://github.com/grafana/rollout-operator) is a specialized Kubernetes operator designed to
coordinate the rolling updates and scaling of pods across multiple StatefulSets, particularly in multi-Availability Zone
(AZ) deployments. This ensures safe and controlled rollouts for stateful services like those in Grafana Mimir and
Grafana Loki, which require careful handling of data consistency during updates or scaling operations.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Grafana® is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc. dba
Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
