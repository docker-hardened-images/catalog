## About Istioctl

Istioctl is the lifecycle management tool for installing and configuring Istio deployments. It functions as a
client-side CLI tool that translates high-level declarative Istio configurations into Kubernetes manifests, providing
simplified installation and upgrade workflows without requiring in-cluster reconciliation.

Key responsibilities of Istioctl:

- **Installation & Upgrade**: Generates and applies Istio installation manifests using configuration profiles
- **Configuration Translation**: Converts high-level settings into low-level Kubernetes resource definitions
- **Manifest Generation**: Produces complete YAML manifests for review before applying to the cluster
- **Component Configuration**: Manages configuration of all Istio components including pilot, gateways, and optional
  add-ons
- **istioctl Integration**: Includes the istioctl command-line tool for mesh inspection, debugging, and cluster
  operations
- **Automatic Validation**: Validates Istio configurations and provides helpful error messages
- **Profile Management**: Offers multiple installation profiles (default, demo, minimal, etc.) as starting points for
  customization

The istioctl simplifies the initial Istio deployment and upgrade process by abstracting complexity and providing a
declarative interface. It's designed to work seamlessly with Kubernetes tooling and CI/CD pipelines.

For more information about Istioctl, visit https://istio.io/latest/docs/setup/install/istioctl/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Istio® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
