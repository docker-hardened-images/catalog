# Codex for Docker Sandboxes

This v3 workload Kit packages [Codex](https://developers.openai.com/codex/cli) for Docker Sandboxes. It includes the
agent and a development environment. Start the workload to use Codex in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/codex:latest /path/to/workspace
```

## Kit arguments

Set these arguments when creating the sandbox with `--kit-arg <name>=<value>`. Repeat the flag for multiple arguments.
Use `--kit-arg <kit>.<name>=<value>` to target one kit in a composition, as in the example below.

| Argument          | Default | Description                                                                          | Accepted values                                                                              |
| ----------------- | ------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `model`           | `""`    | Codex model to use (config.toml `model`); empty keeps the CLI default                | Letters, digits, `.`, `_`, and `-`.                                                          |
| `reasoningEffort` | `""`    | Reasoning effort (config.toml `model_reasoning_effort`); empty keeps the CLI default | Empty, `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`, `ultra`, or `persistent`. |

An empty value keeps the agent default. The model must be available to your provider account, and the selected model
must support the requested effort or thinking level. These are kit configuration inputs, separate from agent
command-line arguments passed after `--`.

```console
sbx run sbx/codex:latest \
  --kit-arg codex.model=gpt-5 --kit-arg codex.reasoningEffort=high \
  /path/to/workspace
```

## Authentication and configuration

Bind an OpenAI API key on the host with `sbx secret set openai`. For a ChatGPT login, run
`sbx secret set openai --oauth` on the host. You can also sign in from Codex inside the sandbox. Host-bound credentials
remain proxy-managed.

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

The agent owns the Codex install. To move to a newer release inside a sandbox, run `codex update`. A new sandbox starts
from the release this Kit pins.

## Related kits

- [`sbx/codex-acp`](https://hub.docker.com/r/sbx/codex-acp) provides the ACP adapter for the composed agent.
- [`sbx/codex-mixin`](https://hub.docker.com/r/sbx/codex-mixin) provides the agent overlay for a compatible workload.
- [`sbx/codex-sessions`](https://hub.docker.com/r/sbx/codex-sessions) provides host-backed conversation state.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Codex and OpenAI are trademarks of OpenAI, L.L.C. Product names and logos do not imply sponsorship or endorsement.
