## About WireMock GUI

WireMock GUI is a community fork of WireMock by Christopher Holomek (`github.com/holomekc/wiremock`) that embeds an
Angular admin webapp into the standalone JAR. The webapp is served at `/__admin/webapp` and provides a browser-based
interface for managing stubs, inspecting the live request log, recording from upstream APIs, and editing response body
files — all on top of the unmodified WireMock admin API.

The fork tracks upstream WireMock releases and adds only the GUI overlay; the standard WireMock admin API at
`/__admin/*` remains fully available alongside the webapp.

## Relationship to upstream WireMock

This image is based on `github.com/holomekc/wiremock`, an upstream-aligned fork of `github.com/wiremock/wiremock`. The
non-GUI WireMock is available as [`dhi/wiremock`](https://hub.docker.com/r/dhi/wiremock). Choose `dhi/wiremock-gui` when
you want the interactive admin webapp; choose `dhi/wiremock` when you only need the programmatic admin API.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

WireMock is a trademark of WireMock Inc. and the WireMock open-source project. This image is based on a community fork
by Christopher Holomek (github.com/holomekc). Docker is not affiliated with, endorsed by, or sponsored by WireMock Inc.
or Christopher Holomek. Use of the WireMock name and marks is for identification purposes only. All other third-party
product names, logos, and trademarks are the property of their respective owners and are used solely for identification.
Docker claims no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
