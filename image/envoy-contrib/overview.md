## About Envoy Contrib

Envoy is a high-performance L7 proxy and communication bus designed for modern, cloud-native applications. It provides
advanced features for load balancing, observability, and service mesh capabilities, making it an essential component in
modern microservices architectures.

Envoy Contrib is the same proxy built with Envoy's contrib extensions compiled in. Contrib extensions live in the
upstream `contrib/` tree and are maintained to a lower support bar than core extensions, so upstream ships them in a
separate binary rather than enabling them by default. They add protocol-aware filters and other integrations that the
core binary does not carry, including the Postgres, MySQL, SIP, and RocketMQ proxies, the Kafka broker and mesh filters,
the Golang HTTP and network filters, the Hyperscan regex engine and input matcher, the peak-EWMA load balancing policy,
and the SXG filter.

Use this image when your Envoy configuration references a contrib extension. If it does not, prefer `dhi/envoy`, which
ships a smaller binary with a smaller attack surface.

For more details, visit https://www.envoyproxy.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Envoy® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
