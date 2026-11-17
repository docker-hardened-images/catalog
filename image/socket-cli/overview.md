## About Socket CLI

[Socket CLI](https://github.com/SocketDev/socket-cli) is the official command-line tool for
[Socket.dev](https://socket.dev), a supply-chain security platform. It scans npm, pnpm, and yarn projects for malicious
packages, typosquats, and known vulnerabilities, wraps `npm`/`npx` to score packages before they install, and integrates
into CI pipelines to gate merges on Socket's security policy.

The image bundles the `socket` CLI (plus the `socket-npm`, `socket-npx`, `socket-pnpm`, and `socket-yarn` wrapper entry
points) built from Socket's [socket-cli](https://github.com/SocketDev/socket-cli) source. Commands that need a Socket
API token (scanning, package scoring, patch application) require `SOCKET_CLI_API_TOKEN` or `socket login`. A handful of
commands (`socket fix`, `socket cdxgen`, `--reach` reachability analysis) lazily download additional tooling via `npx`
on first use; they require the `dev` variant (which ships npm and git -- the runtime variant does not) plus outbound
network access to the npm registry.

For more details, visit https://socket.dev and https://github.com/SocketDev/socket-cli.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
