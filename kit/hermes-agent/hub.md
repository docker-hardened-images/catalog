# Hermes Agent for Docker Sandboxes

This v3 workload Kit packages [Hermes Agent](https://github.com/NousResearch/hermes-agent) for Docker Sandboxes. It
includes the agent and a development environment. Start the workload to use Hermes Agent in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/hermes-agent:latest /path/to/workspace
```

## Kit arguments

This kit has no create-time kit arguments.

## Authentication and configuration

Bind the provider credentials you use on the host. Supported services are `anthropic`, `openai`, `openrouter`, and
`copilot`. For example, run `sbx secret set openrouter`. Credentials remain proxy-managed.

The kit includes the Anthropic and ACP extras in a private Python 3.14 environment. Runtime package installation in that
environment is disabled.

Run `hermes model` to choose a provider and model. For Anthropic, use an API key or an existing host-managed Claude
subscription login. An API key takes priority when both are available.

Keep authentication on the host. Do not use Hermes-native login or `claude setup-token` inside the sandbox, because
those flows can write real tokens into files the agent can read.

ACP support is included. Configure an ACP client to open a non-TTY stream to the sandbox.

```console
sbx exec -i <sandbox> hermes acp
```

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

If a tool cannot reach a service, run `sbx policy log` on the host to identify blocked destinations.

## Related kits

- [`sbx/hermes-agent-mixin`](https://hub.docker.com/r/sbx/hermes-agent-mixin) provides the agent overlay for a
  compatible workload.
- [`sbx/hermes-agent-sessions`](https://hub.docker.com/r/sbx/hermes-agent-sessions) provides host-backed conversation
  state.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Hermes Agent is a project of Nous Research. Product names and logos do not imply sponsorship or endorsement.
