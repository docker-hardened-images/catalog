## About Docker dind

Docker dind (Docker-in-Docker) runs a full Docker Engine, `dockerd`, inside a container so that Docker CLI clients can
build and run nested containers without accessing the host's Docker socket. It's commonly used for CI/CD pipelines,
testcontainers, and other automation that needs an isolated Docker daemon per job or per test run. The image ships
`dockerd`, the `docker` CLI, `docker buildx`, `containerd`, and `runc`, and generates TLS certificates automatically at
startup so clients can connect securely over the network.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Docker and the Docker logo are trademarks or registered trademarks of Docker, Inc. Any use by Docker of other companies'
trademarks, product names, or logos are for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
