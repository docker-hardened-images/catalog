## About Harbor Redis

Harbor Redis is the Redis component used by the [Harbor](https://goharbor.io/) container registry — a CNCF-graduated
open-source project for storing, signing, and scanning container images. This image provides a drop-in replacement for
the upstream `goharbor/redis-photon` image, shipping a Harbor-specific `redis.conf` and healthcheck script on top of
Redis 7.2. Harbor uses Redis for three purposes: user session management, background job queuing via
`harbor-jobservice`, and API response caching and rate limiting.

This image is purpose-built for Harbor deployments and is not a general-purpose Redis image. It is designed to be used
as a component within a full Harbor installation, whether deployed via Docker Compose or Kubernetes.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Harbor™ is a trademark of the Cloud Native Computing Foundation (CNCF). Redis® is a registered trademark of Redis Ltd.
