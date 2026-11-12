## About Datadog Cluster Agent

The Datadog Cluster Agent is a Kubernetes-native companion to the Datadog node Agent that runs centralized cluster-level
checks (such as a single source of truth for cluster checks dispatched to other agents), exposes a custom-metrics
provider used by Horizontal Pod Autoscalers, and proxies all node-agent traffic to the Kubernetes API server. By
consolidating cluster-scoped responsibilities into a single workload, the Cluster Agent reduces load on `kube-apiserver`
and avoids the noise of running cluster checks on every node.

This Docker Hardened Image ships the `datadog-cluster-agent` binary together with `cws-instrumentation` and
`secret-generic-connector`, the `nosys-seccomp` shim used by the upstream image, and the cluster-agent configuration
templates found in `/etc/datadog-agent/`.

## About Docker Hardened Images

Docker Hardened Images (DHI) are minimal, secure container images maintained by Docker. They contain only what's needed
to run the application -- no shell, no package manager, and no unnecessary binaries in the runtime variant. DHI images
are continuously scanned, patched, and signed, with cryptographic provenance and a complete SBOM.

### Why use Docker Hardened Images?

- Continuously scanned, patched, and rebuilt to eliminate known CVEs.
- Minimal attack surface: no shell, no package manager, and no unnecessary tooling in runtime variants.
- Non-root by default and runtime hardening applied across the catalog.
- Cryptographically signed with full provenance and a complete SBOM so deployments can be audited and verified.

## Trademarks

*Datadog* is a registered trademark of *Datadog, Inc.* This image is not affiliated with, endorsed by, or sponsored by
Datadog, Inc. The image is provided to make it convenient to run upstream Datadog Cluster Agent releases inside the
Docker Hardened Images program.
