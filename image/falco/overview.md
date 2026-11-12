## About Falco

Falco is a CNCF-graduated cloud-native runtime security tool. It monitors syscalls and container/Kubernetes events in
real time, evaluating them against a library of rules to detect anomalous behavior — such as unexpected shell spawns,
sensitive file reads, or privilege escalation attempts inside a running container or host.

This image builds Falco from source using its **modern eBPF (CO-RE)** driver only. Modern eBPF is bundled directly into
the `falco` binary and requires no separate driver-loader, no DKMS, and no kernel headers on the host — only a Linux
kernel 5.8+ with BTF support. The legacy kernel-module and legacy-eBPF drivers are out of scope for this image.

Falco loads its eBPF probe into the kernel and therefore runs as **root** with elevated capabilities — this is inherent
to how Falco captures syscalls, not something added by hardening.

This image builds the `container` plugin (container metadata enrichment) from source rather than using upstream's
pre-built binary — Falco's default bundled rules file declares a hard requirement on this plugin and will not load or
start without it.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Falco® and the Falco logo are trademarks of The Linux Foundation, used under the Cloud Native Computing Foundation's
Falco brand guidelines. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
