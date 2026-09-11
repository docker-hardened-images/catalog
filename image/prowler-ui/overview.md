## About Prowler UI

Prowler UI is the web interface for Prowler App. It presents cloud security findings, resource inventory, provider and scan management, compliance results, attack paths, integrations, and Lighthouse AI workflows through a Next.js application.

## About this image

This image builds Prowler UI 5.36.0 with the upstream pnpm lockfile and packages the Next.js standalone server output. The runtime contains Node.js 24 and only the files traced by Next.js, static assets, and public assets. It listens on port 3000 as nonroot uid 65532.

Runtime configuration is read when `node server.js` starts rather than being embedded at build time. This allows the same immutable image to be promoted across environments. The Prowler API and an authentication secret must be supplied by the deployment.

## About Docker Hardened Images

Docker Hardened Images are built to meet high security and compliance standards. They provide a minimal, continuously maintained foundation, signed provenance, and a complete Software Bill of Materials (SBOM) and VEX metadata.

## Trademarks

Prowler is a trademark of Prowler, Inc. All third-party product names, logos, and trademarks are the property of their respective owners and are used solely for identification. Docker claims no affiliation, sponsorship, or endorsement.
