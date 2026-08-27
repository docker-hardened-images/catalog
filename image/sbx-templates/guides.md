## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/sbx-templates:<tag>`
- Mirrored image: `<your-namespace>/dhi-sbx-templates:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

These images are the agent templates used by Docker Sandboxes to run AI coding agents inside isolated containers. Each
agent is published as a separate **tag** of the single `sbx-templates` repository (for example `claude-code`, `codex`,
or `shell`). They are meant to be launched by the `sbx` CLI (`docker sandbox`), which pulls the right tag, mounts your
workspace, and runs the agent for you—you normally do not start them with a bare `docker run`.

### What's included in this image

Every `sbx-templates` tag builds on a common base that includes:

- `docker` — Docker CLI for container management
- `git` — version control
- `gh` — GitHub CLI for repository management
- `uv` — fast Python package installer and resolver

Full-tier tags additionally bundle language toolchains (Go, Node.js, Python, and a JDK) along with common shell
utilities. All tags run as the nonroot `agent` user, use `/home/agent/workspace` as the working directory, and use
`tini` as the entrypoint so agents launched with `docker exec` are reaped correctly.

## Run agents with the `sbx` CLI

These images are launched by Docker Sandboxes, not started by hand. Install the `sbx` CLI plugin (invoked as
`docker sandbox`, or as the standalone `sbx` binary), then let it create the sandbox, pull the correct tag, mount your
workspace, and run the agent.

### Enable the hardened (DHI) templates

By default the `sbx` CLI pulls the standard `docker/sandbox-templates` images. Point it at the hardened
`dhi.io/sbx-templates` equivalents by turning on the `platform.images.useDHI` setting:

```bash
docker sandbox settings set platform.images.useDHI true
```

Or enable it for a single shell session with an environment variable:

```bash
export DOCKER_SANDBOXES_USE_DHI=1
```

With the toggle on, `sbx` swaps `docker/sandbox-templates:<tag>` for `dhi.io/sbx-templates:<tag>` (same tag) when it
resolves an agent's default template image. The daemon pulls the image the first time you run the agent; authenticate to
the registry with `docker login dhi.io` if the pull requires it.

### Run an agent

Create and run a sandbox for an agent in a workspace directory:

```bash
docker sandbox run claude /path/to/workspace
```

Run the same command again to reuse the existing sandbox, so your session and files persist. To open a plain sandbox
with no preinstalled agent, use the `shell` agent:

```bash
docker sandbox run shell /path/to/workspace
```

### Agent-to-tag mapping

Each `sbx` agent resolves to a tag of this repository. The CLI selects the Docker-in-Docker (`-docker`) variant by
default so the agent can build and run containers inside its sandbox:

| `sbx` agent    | `sbx-templates` tag   | Agent                  |
| -------------- | --------------------- | ---------------------- |
| `claude`       | `claude-code-docker`  | Anthropic Claude Code  |
| `codex`        | `codex-docker`        | OpenAI Codex CLI       |
| `cursor`       | `cursor-agent-docker` | Cursor Agent           |
| `gemini`       | `gemini-docker`       | Google Gemini CLI      |
| `copilot`      | `copilot-docker`      | GitHub Copilot CLI     |
| `droid`        | `droid-docker`        | Factory Droid          |
| `kiro`         | `kiro-docker`         | Kiro                   |
| `opencode`     | `opencode-docker`     | OpenCode               |
| `docker-agent` | `docker-agent-docker` | Docker Agent           |
| `shell`        | `shell-docker`        | Plain shell (no agent) |

Non-`-docker` tags (for example `claude-code` or `shell`) provide the same environment without the bundled Docker
Engine, and a `-minimal` tag (for example `claude-code-minimal`) omits the bundled language toolchains for a smaller
image.

### Extend an agent with kits

Agents can be composed with additional kits at run time using `--kit` (a local directory or a packaged kit):

```bash
docker sandbox run claude --kit ./my-extension/ /path/to/workspace
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
