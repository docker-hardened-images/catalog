# Google Antigravity for Docker Sandboxes

This v3 workload Kit packages [Google Antigravity](https://antigravity.google) for Docker Sandboxes. It includes the
agent and a development environment. Start the workload to use Google Antigravity in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/antigravity:latest /path/to/workspace
```

The workload starts `agy --dangerously-skip-permissions`, which allows tool execution without approval prompts. For
native approval behavior, run `agy` directly with `sbx exec`.

## Kit arguments

This kit has no create-time kit arguments.

## Authentication and configuration

Bind a Gemini API key on the host with `sbx secret set google` to use the Gemini provider. The runtime supplies a
proxy-managed credential. With no bound Google credential, `agy` uses its interactive Google sign-in.

For Google OAuth, skip the optional `google` credential during setup. Open the sign-in URL in your browser, then paste
the authorization code into the terminal. To switch from API-key mode to OAuth, remove the host's `google` credential
binding and recreate the sandbox.

When the runtime supplies an MCP gateway, the kit registers it automatically in `~/.gemini/config/mcp_config.json`.
Existing unrelated settings and server entries are preserved.

ACP support is included. Configure an ACP client to open a non-TTY stream to the sandbox.

```console
sbx exec -i <sandbox> agy acp --dangerously-skip-permissions
```

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

If a tool cannot reach a service, run `sbx policy log` on the host to identify blocked destinations.

## Related kits

- [`sbx/antigravity-mixin`](https://hub.docker.com/r/sbx/antigravity-mixin) provides the agent overlay for a compatible
  workload.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Google and Antigravity are trademarks of Google LLC. Product names and logos do not imply sponsorship or endorsement.
