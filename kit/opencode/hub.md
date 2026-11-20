# OpenCode for Docker Sandboxes

This v3 workload Kit packages [OpenCode](https://opencode.ai) for Docker Sandboxes. It includes the agent and a
development environment. Start the workload to use OpenCode in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/opencode:latest /path/to/workspace
```

To run a single prompt in a running sandbox:

```console
sbx exec <sandbox> opencode run "Summarize this repository"
```

The kit configures OpenCode to allow tool execution without approval prompts.

## Kit arguments

Set these arguments when creating the sandbox with `--kit-arg <name>=<value>`. Repeat the flag for multiple arguments.
Use `--kit-arg <kit>.<name>=<value>` to target one kit in a composition, as in the example below.

| Argument          | Default | Description                                                                           | Accepted values                                                                   |
| ----------------- | ------- | ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `model`           | `""`    | OpenCode model as provider/model (opencode.json `model`); empty keeps the CLI default | Empty, or a `provider/model` value. Letters, digits, `.`, `_`, `/`, `:`, and `-`. |
| `reasoningEffort` | `""`    | Model variant such as `high` or `max`; needs `model`; empty keeps the model default   | Letters, digits, `.`, `_`, and `-`.                                               |

An empty value keeps the agent default. The model must be available to your provider account. OpenCode applies an effort
as a variant of a named model, and each model has its own variant names, so `reasoningEffort` needs `model` and the
sandbox is not created without it. These are kit configuration inputs, separate from agent command-line arguments passed
after `--`.

```console
sbx run sbx/opencode:latest \
  --kit-arg opencode.model=anthropic/claude-sonnet-4-5 --kit-arg opencode.reasoningEffort=high \
  /path/to/workspace
```

The kit writes the selection to `~/.config/opencode/opencode.json` as `provider/model#variant` when the sandbox is
created and keeps the other settings in that file.

## Authentication and configuration

Bind the provider credentials you use on the host. Supported services are `github`, `google`, `groq`, `openai`,
`anthropic`, `openrouter`, and `xai`. For example, run `sbx secret set anthropic`. OpenAI also supports a ChatGPT OAuth
credential through `sbx secret set openai --oauth`. Host-bound credentials remain proxy-managed.

A host `github` credential also enables OpenCode's GitHub Copilot model provider. Configure it with
`sbx secret set github` on the host. The credential needs access to Copilot.

When the runtime supplies an MCP gateway, the kit registers it automatically in `~/.config/opencode/opencode.json`.
Existing unrelated settings and server entries are preserved.

ACP support is included. Configure an ACP client to open a non-TTY stream to the sandbox.

```console
sbx exec -i <sandbox> opencode acp
```

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

If a tool cannot reach a service, run `sbx policy log` on the host to identify blocked destinations. Additional
language-server downloads may need extra destinations in the runtime network policy.

The agent owns the OpenCode install. To move to a newer release inside a sandbox, run `opencode upgrade`. A new sandbox
starts from the release this Kit pins.

## Related kits

- [`sbx/opencode-mixin`](https://hub.docker.com/r/sbx/opencode-mixin) provides the agent overlay for a compatible
  workload.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

OpenCode is an open-source coding agent. Product names and logos do not imply sponsorship or endorsement.
