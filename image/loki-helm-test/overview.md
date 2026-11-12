## About Loki Helm Test

Loki Helm Test image provides a collection of go tests that test if a Loki canary is running correctly. It's primary use
is to test that the helm chart is working correctly by using metrics from the Loki canary. In the helm chart, the
template for this test is only available if you are running both the Loki canary and have self monitoring enabled (as
the Loki canary's logs need to be in Loki for it to work). However, this image can be run against any running Loki
canary using

For more details, visit https://github.com/grafana/loki/tree/main/production/helm/loki/src/helm-test⁠.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Grafana® Loki® is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc.
dba Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
