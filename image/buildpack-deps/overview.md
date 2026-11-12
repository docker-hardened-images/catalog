## About buildpack-deps

buildpack-deps is a build environment for compiling software from source. It bundles a C/C++ toolchain, source control
clients, and the development headers that language package managers most often look for, so commands like `gem install`,
`npm install`, or `pip install` can build native extensions without you tracking down each header package first.

It is the base that many language images are built from, and it is useful on its own as the build stage of a multi-stage
Dockerfile.

Upstream project: https://github.com/docker-library/buildpack-deps

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. buildpack-deps is a Docker Official Image maintained by Docker. Debian is a
trademark of Software in the Public Interest, Inc. All other third-party product names, logos, and trademarks are the
property of their respective owners and are used solely for identification. Docker claims no interest in those marks,
and no affiliation, sponsorship, or endorsement is implied.
