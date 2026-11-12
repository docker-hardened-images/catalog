## About Azure CLI

Azure CLI (`az`) is Microsoft's cross-platform command-line tool for creating and managing resources in Microsoft Azure.
It provides commands for provisioning and operating services such as virtual machines, storage, networking, Azure
Kubernetes Service, Key Vault, and the broader Azure platform, and it is commonly used interactively and in CI/CD
pipelines and automation scripts.

This image packages the `az` command and its Python runtime so it can be run directly as a container. The entry point is
`az`, so pass any Azure CLI arguments after the image reference (for example `version`, `login`, or `group list`). Azure
CLI stores its configuration, logs, token cache, and telemetry state under a config directory; this image sets
`AZURE_CONFIG_DIR=/azure` and creates that directory writable for the nonroot runtime user. Mount a volume at `/azure`
to persist sign-in state across container runs.

For more details, see the [upstream project](https://github.com/Azure/azure-cli).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Microsoft Azure and Azure are trademarks of the Microsoft group of companies. Any use by Docker is for referential
purposes only and does not indicate sponsorship, endorsement, or affiliation. All other third-party product names,
logos, and trademarks are the property of their respective owners and are used solely for identification.
