## About JupyterHub

JupyterHub is a multi-user server for Jupyter notebooks, designed to support classes, research groups, or teams. The hub
spawns and proxies single-user notebook servers, enabling pluggable
[authenticators](https://jupyterhub.readthedocs.io/en/stable/reference/authenticators.html) and
[spawners](https://jupyterhub.readthedocs.io/en/stable/reference/spawners.html) so administrators can adapt it to their
environment. This Docker Hardened Image packages JupyterHub from [upstream](https://github.com/jupyterhub/jupyterhub)
together with the [Configurable HTTP Proxy](https://github.com/jupyterhub/configurable-http-proxy) so the hub can run
end to end.

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
