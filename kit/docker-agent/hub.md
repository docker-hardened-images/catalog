# Docker Agent for Docker Sandboxes

This v3 workload Kit packages [Docker Agent](https://github.com/docker/docker-agent) for Docker Sandboxes. It includes
the agent and a development environment. Start the workload to use Docker Agent in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/docker-agent:latest /path/to/workspace
```

A plain launch opens the interactive agent picker. The workload uses `--yolo` to allow tool execution without approval
prompts.

To run a single prompt in a running sandbox, select the `default` agent explicitly and omit `--agent-picker`. The picker
requires a terminal and cannot be combined with `--exec`.

```console
sbx exec <sandbox> docker-agent run --yolo --exec default "Summarize this repository"
```

For native approval prompts, run `docker-agent run default` directly with `sbx exec`.

## Kit arguments

This kit has no create-time kit arguments.

## Authentication and configuration

Bind the provider credentials your agent configuration uses on the host. Supported services are `anthropic`, `github`,
`google`, `mistral`, `nebius`, `openai`, `openrouter`, and `xai`. For example, run `sbx secret set anthropic`.
Credentials remain proxy-managed.

Automatic agent updates are disabled. Select a newer kit tag when you want a different Docker Agent release.

Use literal provider API keys. A Claude subscription login does not supply an Anthropic API key, and a ChatGPT
subscription does not supply an OpenAI API key. Bind the matching API key on the host.

ACP support is included. Configure an ACP client to open a non-TTY stream to the sandbox.

```console
sbx exec -i <sandbox> docker-agent serve acp default
```

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

If a tool cannot reach a service, run `sbx policy log` on the host to identify blocked destinations.

## Related kits

- [`sbx/docker-agent-mixin`](https://hub.docker.com/r/sbx/docker-agent-mixin) provides the agent overlay for a
  compatible workload.
- [`sbx/docker-agent-sessions`](https://hub.docker.com/r/sbx/docker-agent-sessions) provides host-backed conversation
  state.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Docker and the Docker logo are trademarks or registered trademarks of Docker, Inc. Product names and logos do not imply
sponsorship or endorsement.
