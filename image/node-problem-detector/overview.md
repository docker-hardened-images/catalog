## About Node Problem Detector

Node Problem Detector is a Kubernetes daemon that runs on each node — typically as a DaemonSet — to detect node-level
problems such as kernel deadlocks, corrupted file systems, unresponsive container runtimes, and hardware faults, and
report them to the API server as Events and NodeConditions. This image is built with journald support enabled and ships
the `node-problem-detector` daemon along with the `health-checker` and `log-counter` helper binaries.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes and the Kubernetes logo are registered trademarks of The Linux Foundation. All rights in the mark are
reserved to The Linux Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
