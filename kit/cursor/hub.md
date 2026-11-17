# Cursor for Docker Sandboxes

This v3 workload Kit packages [Cursor](https://cursor.com) for Docker Sandboxes. It includes the agent and a development
environment. Start the workload to use Cursor in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/cursor:latest /path/to/workspace
```

The workload starts `cursor-agent --yolo`, which allows tool execution without approval prompts. To use native approval
prompts, run `cursor-agent` directly with `sbx exec`. Workspace trust and tool approval are separate settings.

## Kit arguments

This kit has no create-time kit arguments.

## Authentication and configuration

Bind a Cursor API key or Cursor OAuth credential through the host runtime's `cursor` service. For an API key, run
`sbx secret set cursor` on the host. The runtime supplies credential sentinels, and the kit pre-trusts the mounted
workspace.

ACP support is included. Configure an ACP client to open a non-TTY stream to the sandbox.

```console
sbx exec -i <sandbox> cursor-acp cursor-agent --force acp
```

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

If a tool cannot reach a service, run `sbx policy log` on the host to identify blocked destinations.

## Related kits

- [`sbx/cursor-mixin`](https://hub.docker.com/r/sbx/cursor-mixin) provides the agent overlay for a compatible workload.
- [`sbx/cursor-sessions`](https://hub.docker.com/r/sbx/cursor-sessions) provides host-backed conversation state.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Cursor is a product of Anysphere, Inc. Product names and logos do not imply sponsorship or endorsement.
