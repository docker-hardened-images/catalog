# cloudflared

`cloudflared` is the Cloudflare Tunnel client daemon. It establishes a secure, outbound-only connection between your local environment and the Cloudflare network, allowing you to expose web servers and services securely to the internet without opening inbound ports on your firewall or exposing your origin IP address.

## Features

- **Outbound-Only Connections**: Connects directly to Cloudflare edge routing without exposing public ports.
- **Identity & Access Management**: Integrates with Cloudflare Access for context-aware authentication.
- **Resiliency**: Built on top of Anycast routing, featuring multiple tunnels with automated failover.
