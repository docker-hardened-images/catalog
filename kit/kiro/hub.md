# Kiro for Docker Sandboxes

This v3 workload Kit packages [Kiro](https://kiro.dev) for Docker Sandboxes. It includes the agent and a development
environment. Start the workload to use Kiro in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/kiro:latest /path/to/workspace
```

The workload starts `kiro-cli chat --trust-all-tools`, which allows tool execution without approval prompts. For native
approval behavior, run `kiro-cli chat` directly with `sbx exec`.

## Kit arguments

This kit has no create-time kit arguments.

## Authentication and configuration

Run `kiro-cli login` inside the sandbox before starting a chat. This kit does not declare a proxy-managed credential
service. Kiro manages its own sign-in state.

Sign-in state survives stop/start of the same sandbox but is lost when you recreate it. Kiro's sign-in state is not
persisted to the host.

The default network policy permits `oidc.us-east-1.amazonaws.com:443`. If you use IAM Identity Center in another region,
allow `oidc.<region>.amazonaws.com:443` in the host runtime's network policy. Use `sbx policy log` on the host to
identify a blocked login endpoint.

When the runtime supplies an MCP gateway, the kit registers it automatically in `~/.kiro/settings/mcp.json`. Startup
replaces this entire file whenever a gateway is configured. Back up custom entries before restarting the sandbox.

ACP support is included. Configure an ACP client to open a non-TTY stream to the sandbox.

```console
sbx exec -i <sandbox> kiro-cli acp
```

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

If a tool cannot reach a service, run `sbx policy log` on the host to identify blocked destinations.

## Related kits

- [`sbx/kiro-mixin`](https://hub.docker.com/r/sbx/kiro-mixin) provides the agent overlay for a compatible workload.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Kiro is a product of Amazon Web Services. Product names and logos do not imply sponsorship or endorsement.
