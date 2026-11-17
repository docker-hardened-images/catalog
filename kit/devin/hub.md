# Devin for Docker Sandboxes

This v3 workload Kit packages [Devin](https://devin.ai) for Docker Sandboxes. It includes the agent and a development
environment. Start the workload to use Devin in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/devin:latest /path/to/workspace
```

The workload starts `devin --permission-mode dangerous --respect-workspace-trust=false`, which allows tool execution
without approval prompts. For native approval behavior, run the `devin` wrapper directly with `sbx exec`.

## Kit arguments

This kit has no create-time kit arguments.

## Authentication and configuration

Run `devin` and complete its sign-in flow inside the sandbox. The `devin` wrapper replaces the durable credential on
disk with a proxy placeholder before launching `devin-cli`. Use the wrapper for interactive sessions.

Devin embeds an intermediate OAuth token in a protobuf request body that the proxy cannot rewrite. The kit permits that
real, short-lived intermediate token to enter the sandbox, which a runtime policy may refuse. The durable account
credential remains proxy-held.

When the runtime supplies an MCP gateway, the kit registers it automatically in `~/.config/devin/mcp_config.json`.
Startup replaces this entire file whenever a gateway is configured. Back up custom entries before restarting the
sandbox.

ACP support is included. Configure an ACP client to open a non-TTY stream to the sandbox.

```console
sbx exec -i <sandbox> devin-cli acp
```

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

If a tool cannot reach a service, run `sbx policy log` on the host to identify blocked destinations.

## Related kits

- [`sbx/devin-mixin`](https://hub.docker.com/r/sbx/devin-mixin) provides the agent overlay for a compatible workload.
- [`sbx/devin-sessions`](https://hub.docker.com/r/sbx/devin-sessions) provides host-backed conversation state.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Devin is a product of Cognition. Product names and logos do not imply sponsorship or endorsement.
