## About Selenium Hub

Selenium Hub is the central coordinator component of a Selenium Grid, a distributed browser-automation infrastructure.
It receives incoming WebDriver session requests from test clients and routes them to registered Node instances running
real browsers (Chrome, Firefox, Edge, and others). The Hub maintains the session queue, tracks Node availability, and
exposes the Grid UI and WebDriver endpoint on a single port, making it the single entry point for any automation
framework that speaks the W3C WebDriver protocol.

Selenium Grid is part of the broader Selenium project, an open-source umbrella of tools that automate web browsers. Grid
is the deployment model used by teams that need parallel test execution across many browser configurations or
centralized remote WebDriver access for CI/CD pipelines.

For more details, visit https://www.selenium.dev/documentation/grid/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Selenium is a trademark of the Software Freedom Conservancy. All rights in the mark are reserved to the Software Freedom
Conservancy. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
