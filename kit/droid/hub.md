# Factory Droid for Docker Sandboxes

This v3 workload Kit packages [Factory Droid](https://factory.ai) for Docker Sandboxes. It includes the agent and a
development environment. Start the workload to use Factory Droid in an isolated workspace.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/droid:latest /path/to/workspace
```

## Kit arguments

This kit has no create-time kit arguments.

## Authentication and configuration

Bind a Factory API key on the host with `sbx secret set droid`, or use the runtime's Droid OAuth support. Host-bound
credentials remain proxy-managed.

With no bound API key, start `droid` and complete the first-use OAuth flow through the runtime. A bound `droid` API key
takes priority over OAuth.

ACP support is included. Configure an ACP client to open a non-TTY stream to the sandbox.

```console
sbx exec -i <sandbox> droid exec --output-format acp
```

The sandbox supplies the isolation for agent tool execution. Launch the kit through Docker Sandboxes and configure extra
tool or MCP destinations in the runtime network policy as needed.

If a tool cannot reach a service, run `sbx policy log` on the host to identify blocked destinations.

The agent owns the Droid install. To move to a newer release inside a sandbox, run `droid update`. A new sandbox starts
from the release this Kit pins.

## Related kits

- [`sbx/droid-mixin`](https://hub.docker.com/r/sbx/droid-mixin) provides the agent overlay for a compatible workload.
- [`sbx/droid-sessions`](https://hub.docker.com/r/sbx/droid-sessions) provides host-backed conversation state.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Droid is a product of Factory. Product names and logos do not imply sponsorship or endorsement.
