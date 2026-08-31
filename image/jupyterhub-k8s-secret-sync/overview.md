## About JupyterHub K8s Secret Sync

JupyterHub K8s Secret Sync is the ACME certificate sync sidecar used by
[Zero to JupyterHub on Kubernetes](https://z2jh.jupyter.org/) (Z2JH). It runs alongside the proxy pod and syncs a single
file (typically `acme.json` from Traefik) to a Kubernetes Secret, so TLS certificates survive pod restarts. This Docker
Hardened Image tracks the secret-sync component built from the Z2JH
[images/secret-sync](https://github.com/jupyterhub/zero-to-jupyterhub-k8s/tree/main/images/secret-sync) context.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Jupyter, JupyterHub, JupyterLab, and other Jupyter word marks are trademarks of LF Charities, of which Project Jupyter
is a part. All rights in those marks are reserved to LF Charities. Any use by Docker is for referential purposes only
and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a registered trademark of the Linux Foundation in the United States and other countries. Docker's use of
the Kubernetes name is for referential purposes only and does not indicate sponsorship or affiliation with the Linux
Foundation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
