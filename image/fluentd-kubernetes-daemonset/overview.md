## About Fluentd Kubernetes Daemonset

Fluentd Kubernetes Daemonset is the node-level deployment of [Fluentd](https://www.fluentd.org/), an open-source data
collector for the unified logging layer. Run as a Kubernetes DaemonSet, it tails container logs from every node
(`/var/log/containers/*.log`), enriches each record with Kubernetes metadata (namespace, pod, labels, container), and
forwards the result to a log backend.

Each image variant is built for a single output destination (the `<flavor>` in the tag, e.g. `elasticsearch8`, `s3`,
`kafka`, `cloudwatch`). The shared base bundles the Kubernetes metadata, systemd, Prometheus, concat, grok, and
multi-format parser plugins; the flavor adds the output plugin and its dependencies. This mirrors upstream
`fluent/fluentd-kubernetes-daemonset`, which publishes one image per destination from a common template.

For configuration and a sample DaemonSet manifest, see the image guide. For Fluentd itself, visit
https://www.fluentd.org/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Fluentd® and Kubernetes® are trademarks of the Linux Foundation. All rights in the mark are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
