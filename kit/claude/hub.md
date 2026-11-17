# Claude Code for Docker Sandboxes

This v3 workload Kit packages [Claude Code](https://code.claude.com) for Docker Sandboxes. It includes the agent and a
development environment. Start the workload to use Claude Code in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/claude:latest /path/to/workspace
```

## Kit arguments

Set these arguments when creating the sandbox with `--kit-arg <name>=<value>`. Repeat the flag for multiple arguments.
Use `--kit-arg <kit>.<name>=<value>` to target one kit in a composition, as in the example below.

| Argument          | Default | Description                                                              | Accepted values                                            |
| ----------------- | ------- | ------------------------------------------------------------------------ | ---------------------------------------------------------- |
| `model`           | `""`    | Claude model to use (settings.json `model`); empty keeps the CLI default | Letters, digits, `.`, `_`, and `-`.                        |
| `reasoningEffort` | `""`    | Effort level (settings.json `effortLevel`); empty keeps the CLI default  | Empty, `low`, `medium`, `high`, `xhigh`, `max`, or `auto`. |

An empty value keeps the agent default. The model must be available to your provider account, and the selected model
must support the requested effort or thinking level. These are kit configuration inputs, separate from agent
command-line arguments passed after `--`.

```console
sbx run sbx/claude:latest \
  --kit-arg claude.model=claude-sonnet-4-6 --kit-arg claude.reasoningEffort=high \
  /path/to/workspace
```

## Authentication and configuration

Bind an Anthropic API key on the host with `sbx secret set anthropic`, or use a Claude subscription through the
runtime's OAuth support. With no host credential, Claude Code can prompt for `/login` inside the sandbox. Host-bound
credentials remain proxy-managed.

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

## Related kits

- [`sbx/claude-acp`](https://hub.docker.com/r/sbx/claude-acp) provides the ACP adapter for the composed agent.
- [`sbx/claude-mixin`](https://hub.docker.com/r/sbx/claude-mixin) provides the agent overlay for a compatible workload.
- [`sbx/claude-sessions`](https://hub.docker.com/r/sbx/claude-sessions) provides host-backed conversation state.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Claude, Claude Code, and Anthropic are trademarks of Anthropic PBC. Product names and logos do not imply sponsorship or
endorsement.
