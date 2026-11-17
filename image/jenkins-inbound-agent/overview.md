## About Jenkins Inbound Agent

Jenkins Inbound Agent is a specialized Docker image designed for Kubernetes and containerized environments where Jenkins
agents need to automatically connect to a Jenkins controller. Unlike the base Jenkins Agent image, the Inbound Agent
includes an entrypoint script that reads configuration from environment variables and automatically starts the agent
connection, making it ideal for dynamic agent provisioning in Kubernetes clusters, CI/CD pipelines, and container
orchestration platforms.

The image is built on top of the Jenkins Agent base image and includes the Jenkins Remoting library (agent.jar) along
with an entrypoint script that handles the agent startup process. This design pattern is particularly well-suited for
environments where agents are dynamically created and need to establish inbound connections to the Jenkins controller,
such as when using the Kubernetes plugin or running agents in containerized infrastructure.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
