## About JupyterHub K8s Network Tools

JupyterHub K8s Network Tools is the iptables init container used by
[Zero to JupyterHub on Kubernetes](https://z2jh.jupyter.org/) (Z2JH). It runs as a privileged init container before the
main hub pod starts, configuring the host-level iptables rules required for inter-pod communication and network
isolation in the JupyterHub deployment. This Docker Hardened Image tracks the network-tools image built from the Z2JH
[images/network-tools](https://github.com/jupyterhub/zero-to-jupyterhub-k8s/tree/main/images/network-tools) context so
you can deploy the same init workflows with a minimal, supply-chain–reviewed runtime.

This image runs as **root** (UID 0). The `iptables` tool requires `CAP_NET_ADMIN` and kernel-level access to the
netfilter subsystem, which cannot be exercised by an unprivileged user. The chart deploys this image as a privileged
init container; it exits immediately after the iptables rules are applied and does not persist as a long-running
process.

For more details, visit https://z2jh.jupyter.org.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation in the United States and other countries. Docker's use is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Jupyter, JupyterHub, JupyterLab, and other Jupyter word marks are trademarks of LF Charities, of which Project Jupyter
is a part. All rights in those marks are reserved to LF Charities. Any use by Docker is for referential purposes only
and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
