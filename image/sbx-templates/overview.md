## About Docker Sandbox Agent Templates

Docker Sandbox Agent Templates are the container images that power Docker Sandboxes, which run AI coding agents—such as
Claude Code, OpenAI Codex, Gemini CLI, GitHub Copilot, and Cursor Agent—inside isolated Docker containers. Each agent is
published as a distinct tag of the `sbx-templates` repository, built on a shared Debian base that bundles the Docker
CLI, Git, the GitHub CLI, and common developer tooling. Variants with a `-docker` tag suffix additionally include the
Docker Engine for building and running containers inside the sandbox, and a `shell` tag provides the base environment
without a preinstalled agent.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Docker and the Docker logo are trademarks or registered trademarks of Docker, Inc. This listing is prepared by Docker.
All third-party product names, logos, and trademarks—including the names of the AI coding agents packaged in these
images—are the property of their respective owners and are used solely for identification. Docker claims no interest in
those marks, and no affiliation, sponsorship, or endorsement is implied.
