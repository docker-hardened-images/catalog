## About HTTP Echo

HTTP Echo is a lightweight Go web server built by HashiCorp that serves the contents provided at startup as an HTML
page. It accepts a `-text` flag or `TEXT` environment variable and returns that text as the response body for every
incoming HTTP request.

HTTP Echo is commonly used for:

- Testing HTTP proxies, load balancers, and service meshes
- Validating container orchestration and networking configurations
- Running demos and "hello world" style Docker applications

For more details, visit https://github.com/hashicorp/http-echo.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

HashiCorp and Terraform are trademarks of HashiCorp, Inc. This listing is prepared by Docker. All third-party product
names, logos, and trademarks are the property of their respective owners and are used solely for identification. Docker
claims no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
