## About the OpenTelemetry Python Autoinstrumentation

OpenTelemetry Python Autoinstrumentation packages the OpenTelemetry Python auto-instrumentation distribution (0.66b2) in
the layout that the OpenTelemetry Operator expects, so the Operator can copy it into a Python workload through an init
container. The image is published for Debian 13 and Alpine 3.24, with runtime, dev, FIPS, and FIPS dev variants, and it
carries the same bundle tree as the upstream `otel/autoinstrumentation-python` image plus a Python 3.15 interpreter. The
`-fips` variants add the OpenSSL FIPS provider to that interpreter, which does not change the cryptography of the
applications you instrument.

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
