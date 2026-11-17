# Shell for Docker Sandboxes

This v3 workload Kit provides a [Bash development environment](https://docs.docker.com/ai/sandboxes/) for Docker
Sandboxes. It includes Git, GitHub CLI, apt, Docker Engine with Compose and Buildx, common CLI tools, and Python with
pip and uv. It opens a Bash login shell as the nonroot `agent` user with passwordless sudo.

This Kit is built on Docker Hardened Images.

## Run

```console
sbx run sbx/shell:latest /path/to/workspace
```

## Kit arguments

This kit declares no kit arguments. Configure additional features through the kits you compose with it.

## Authentication and configuration

Shell declares no agent credentials or network policy. Composed kits or your sandbox policy must allow the destinations
you need, including the apt sources `deb.debian.org` and `dhi.io`. Install additional development tools with
`sudo apt-get install`.

## Related kits

- Agent mixins, such as [`sbx/claude-mixin`](https://hub.docker.com/r/sbx/claude-mixin) and
  [`sbx/codex-mixin`](https://hub.docker.com/r/sbx/codex-mixin), add an agent to this workload.

## Source and security

For the Kit format and capability contracts, see the
[Sandbox Kit v3 specification](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md).

For runtime setup, see the [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/). For provenance,
SBOM, VEX, and image verification, see the [Docker Hardened Images documentation](https://docs.docker.com/dhi/).

Docker and the Docker logo are trademarks or registered trademarks of Docker, Inc. Product names and logos do not imply
sponsorship or endorsement.
