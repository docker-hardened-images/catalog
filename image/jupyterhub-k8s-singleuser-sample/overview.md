## About JupyterHub K8s Singleuser Sample

JupyterHub K8s Singleuser Sample is the single-user notebook server image used by
[Zero to JupyterHub on Kubernetes](https://z2jh.jupyter.org/) (Z2JH). When JupyterHub spawns a notebook session for a
user, it launches a pod running this image. This Docker Hardened Image tracks the singleuser-sample image built from the
Z2JH [images/singleuser-sample](https://github.com/jupyterhub/zero-to-jupyterhub-k8s/tree/main/images/singleuser-sample)
context and provides JupyterLab together with nbgitpuller and nbclassic.

The container runs as the **jovyan** user (UID **1000**, GID **100**). This is the JupyterHub community standard
single-user account: the name and UID are intentionally fixed so that volume mounts, shared filesystems, and spawner
security contexts align consistently across JupyterHub deployments. Port **8888** is the default JupyterLab listen port.

For more details, visit https://z2jh.jupyter.org.

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

Kubernetes is a registered trademark of the Linux Foundation in the United States and other countries. Any use by Docker
is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
