## About Varnish Cache

Varnish Cache is an open source HTTP accelerator and caching reverse proxy. It sits in front of web and application
servers, stores content in memory, and serves subsequent requests for the same content directly from its cache, reducing
origin load and dramatically improving response times.

Varnish Cache is written in C for maximum performance and uses its own flexible configuration language, VCL (Varnish
Configuration Language), to define request routing, cache behavior, and response manipulation. It supports HTTP/1.1 and
ESI (Edge Side Includes), streaming, grace mode, and a rich module ecosystem (VMODs) for extending functionality.

For more details, see https://varnish-cache.org/ and the upstream source repositories — current **9.x** releases are
published from https://github.com/varnish/varnish, while **8.x** continues to ship from
https://github.com/varnishcache/varnish-cache.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Varnish® is a registered trademark of Varnish Software AS. All rights in the mark are reserved to Varnish Software AS.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
