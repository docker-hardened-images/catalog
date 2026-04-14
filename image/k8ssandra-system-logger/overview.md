## About k8ssandra-system-logger

k8ssandra-system-logger is a small sidecar image that runs Vector (vectordotdev/vector) configured to tail Cassandra
system logs and forward them to stdout. It's intended to be run as a sidecar alongside Cassandra pods to expose
/var/log/cassandra/\*.log on stdout for Kubernetes logging pipelines.

Common use cases include running as a Kubernetes sidecar to collect and forward Cassandra logs, debugging Cassandra node
issues by streaming system logs to cluster-level log collectors, or integrating Cassandra logs into centralized logging
systems via stdout.

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
