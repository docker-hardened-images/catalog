## About SendGrid Python

SendGrid Python is the official Twilio SendGrid client library for the SendGrid Web API v3. It provides a Pythonic
interface for sending transactional and marketing email — building messages, managing templates and contacts, and
calling the full v3 REST API — and is the SDK Twilio SendGrid recommends for Python integrations.

This image is not a runnable service. SendGrid Python is a library with no command-line entrypoint, so the image ships
it preinstalled into a hardened Python 3.14 runtime: the default `python3` interpreter can `import sendgrid` (along with
its `python-http-client`, `cryptography`, and `werkzeug` dependencies) out of the box. Use it to run SendGrid scripts
directly, or as a minimal, low-CVE base image for your own Python application that depends on the SendGrid SDK.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. SendGrid and the SendGrid names and logos are trademarks of Twilio SendGrid, Inc.
All third-party product names, logos, and trademarks are the property of their respective owners and are used solely for
identification. Docker claims no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
