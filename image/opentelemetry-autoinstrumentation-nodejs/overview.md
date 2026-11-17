## About the OpenTelemetry Node.js Autoinstrumentation

OpenTelemetry Node.js Autoinstrumentation packages the OpenTelemetry Node.js auto-instrumentation bundle, the one the
OpenTelemetry Operator ships as its Node.js init image. The operator copies the bundle into a shared volume and loads it
into your application with `NODE_OPTIONS`, instrumenting the application without any code changes.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

OpenTelemetry™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation. For the
Linux Foundation trademark policy, see
[https://www.linuxfoundation.org/legal/trademark-usage](https://www.linuxfoundation.org/legal/trademark-usage).
