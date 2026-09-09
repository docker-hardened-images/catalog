## About this Helm chart

This is a Zero to JupyterHub Docker Hardened Helm chart built from the official upstream Zero to JupyterHub on
Kubernetes chart and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/jupyterhub-k8s-hub`
- `dhi/configurable-http-proxy`
- `dhi/jupyterhub-k8s-secret-sync`
- `dhi/jupyterhub-k8s-network-tools`
- `dhi/jupyterhub-k8s-singleuser-sample`
- `dhi/jupyterhub-k8s-image-awaiter`
- `dhi/kubernetes-pause`
- `dhi/kube-scheduler`
- `dhi/traefik`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://z2jh.jupyter.org/](https://z2jh.jupyter.org/)

### About JupyterHub

JupyterHub lets multiple users run Jupyter notebooks and other interactive computing environments in a shared, managed
Kubernetes cluster. Zero to JupyterHub on Kubernetes (Z2JH) is the official Helm chart for deploying JupyterHub on
Kubernetes.

Official documentation: https://z2jh.jupyter.org/

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

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
