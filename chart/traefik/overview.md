## About this Helm chart

This is a Traefik Docker Hardened Helm chart built from the upstream Traefik Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/traefik`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/traefik/traefik-helm-chart](https://github.com/traefik/traefik-helm-chart)

### About Traefik

Traefik⁠ is a modern HTTP reverse proxy and ingress controller that makes deploying microservices easy.

Traefik integrates with your existing infrastructure components (Kubernetes⁠, Docker⁠, Swarm⁠, Consul⁠, Nomad⁠, etcd⁠,
Amazon ECS⁠, etc.) and configures itself automatically and dynamically.

Pointing Traefik at your orchestrator should be the only configuration step you need.

For more details, visit https://traefik.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Traefik® is a registered trademark of Traefik Labs. Any rights therein are reserved to Traefik Labs. Any use by Docker
is for referential purposes only and does not indicate any sponsorship, endorsement, or affiliation between Traefik
Labs.
