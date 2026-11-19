# GitHub Copilot for Docker Sandboxes

This v3 workload Kit packages [GitHub Copilot](https://github.com/github/copilot-cli) for Docker Sandboxes. It includes
the agent and a development environment. Start the workload to use GitHub Copilot in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/copilot:latest /path/to/workspace
```

The workload starts `copilot --yolo`, which allows tool execution without approval prompts. To use native approval
prompts, run `copilot` directly with `sbx exec`.

## Kit arguments

This kit has no create-time kit arguments.

## Authentication and configuration

Bind the Copilot credential on the host with `sbx secret set copilot`. Git and GitHub CLI access use the separate
`github` service, configured with `sbx secret set github`. Host-bound credentials remain proxy-managed.

The `copilot` credential needs Copilot access. For a fine-grained GitHub token, grant the Copilot Requests permission.
Working git or `gh` authentication alone does not establish Copilot access.

When the runtime supplies an MCP gateway, the kit registers it automatically in `~/.copilot/mcp-config.json`. Existing
unrelated settings and server entries are preserved.

ACP support is included. Configure an ACP client to open a non-TTY stream to the sandbox.

```console
sbx exec -i <sandbox> copilot --acp
```

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

If a tool cannot reach a service, run `sbx policy log` on the host to identify blocked destinations.

The agent owns the Copilot CLI install. To move to a newer release inside a sandbox, run `copilot update`. A new sandbox
starts from the release this Kit pins.

## Related kits

- [`sbx/copilot-mixin`](https://hub.docker.com/r/sbx/copilot-mixin) provides the agent overlay for a compatible
  workload.
- [`sbx/copilot-sessions`](https://hub.docker.com/r/sbx/copilot-sessions) provides host-backed conversation state.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

GitHub and GitHub Copilot are trademarks of GitHub, Inc. Product names and logos do not imply sponsorship or
endorsement.
