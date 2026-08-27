## About Grafana Image Renderer

Grafana Image Renderer is a headless browser service that renders Grafana panels and dashboards as PNG images and PDF
documents. Built with Go and Chromium, it provides a standalone rendering engine that can be used as a remote rendering
service for Grafana instances.

The service uses the Chrome DevTools Protocol to control a headless Chromium browser, enabling high-fidelity rendering
of complex visualizations, custom panels, and data-rich dashboards. It supports internationalization with comprehensive
font coverage for multiple languages including Japanese, Chinese, Thai, Arabic, and more.

Official documentation: https://github.com/grafana/grafana-image-renderer

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Grafana® is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc. dba
Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
