# Pi for Docker Sandboxes

This v3 workload Kit packages [Pi](https://pi.dev) for Docker Sandboxes. It includes the agent and a development
environment. Start the workload to use Pi in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/pi:latest /path/to/workspace
```

## Kit arguments

Set these arguments when creating the sandbox with `--kit-arg <name>=<value>`. Repeat the flag for multiple arguments.
Use `--kit-arg <kit>.<name>=<value>` to target one kit in a composition, as in the example below.

| Argument        | Default | Description                                                                               | Accepted values                                                                                  |
| --------------- | ------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `model`         | `""`    | pi model as provider/model or an Anthropic model ID; empty keeps the CLI default          | A `provider/model` value or an Anthropic model ID. Letters, digits, `.`, `_`, `/`, `:`, and `-`. |
| `thinkingLevel` | `""`    | Thinking level (settings.json `defaultThinkingLevel`); empty keeps pi's default of medium | Empty, `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, or `max`.                             |

An empty value keeps the agent default. The model must be available to your provider account, and the selected model
must support the requested effort or thinking level. These are kit configuration inputs, separate from agent
command-line arguments passed after `--`.

```console
sbx run sbx/pi:latest \
  --kit-arg pi.model=anthropic/claude-sonnet-4-6 --kit-arg pi.thinkingLevel=high \
  /path/to/workspace
```

## Authentication and configuration

Bind an Anthropic API key on the host with `sbx secret set anthropic`. An existing Claude subscription credential on the
host can also supply authentication. Host-bound credentials remain proxy-managed.

Pi runs tool calls without approval prompts, and the kit pre-answers the workspace trust prompt. The sandbox provides
the isolation for these operations.

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

## Related kits

- [`sbx/pi-acp`](https://hub.docker.com/r/sbx/pi-acp) provides the ACP adapter for the composed agent.
- [`sbx/pi-mixin`](https://hub.docker.com/r/sbx/pi-mixin) provides the agent overlay for a compatible workload.
- [`sbx/pi-sessions`](https://hub.docker.com/r/sbx/pi-sessions) provides host-backed conversation state.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Pi is a product of Earendil Works, Inc. Product names and logos do not imply sponsorship or endorsement.
