## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/actions-runner:<tag>`
- Mirrored image: `<your-namespace>/dhi-actions-runner:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this actions-runner image

This Docker Hardened actions-runner image includes:

- The GitHub Actions runner (`config.sh`, `run.sh`, and the underlying `Runner.Listener` binary), installed under
  `/usr/lib/actions-runner`
- `git`, `curl`, `jq`, and `unzip`, used by the runner and by actions/steps that shell out to them
- The Docker CLI and `docker buildx` plugin, for workflows that run Docker container actions or `docker build` steps
  directly against a mounted or sidecar Docker daemon. This image has no `docker` group, so a mounted or sidecar Docker
  socket is only usable by `nonroot` if you add its GID with `docker run --group-add <socket-gid>` (or the equivalent
  field on your scheduler), matching whatever group actually owns the socket you're mounting.
- [Container hooks](https://github.com/actions/runner-container-hooks) for both Kubernetes (`k8s`) and Docker (`docker`)
  execution modes, staged under `/usr/share/gha-runner-container-hooks/{k8s,docker}`, for use with the
  [Actions Runner Controller](https://github.com/actions/actions-runner-controller)

## Start an actions-runner container

### Check the version

```bash
$ docker run --rm dhi.io/actions-runner:<tag> --version
```

### Register and run a runner

The runner is a two-step process: `config.sh` registers the runner with a repository or organization, then `run.sh`
starts listening for jobs. Both scripts live under `/usr/lib/actions-runner`, which is owned by the nonroot user so the
runner can write its own registration state (`.runner`, `.credentials`) and work/diag directories directly alongside its
binaries.

Because registration state lives inside that same directory, don't mount a volume over the whole
`/usr/lib/actions-runner` path - doing so shadows the runner binaries themselves, and since Docker only seeds a named
volume from the image on its first use, later `docker pull`s of a newer image tag would never reach the runner tree
underneath it. Run registration and the listener as a single container instead, so both steps see the same
image-provided binaries:

```bash
$ docker run -d --name actions-runner \
  --entrypoint /bin/bash \
  dhi.io/actions-runner:<tag> \
  -c '[ -f /usr/lib/actions-runner/.runner ] || /usr/lib/actions-runner/config.sh --url https://github.com/<org>/<repo> --token <registration-token> --unattended; exec /usr/lib/actions-runner/run.sh'
```

The `[ -f .runner ] ||` guard is required: `config.sh` refuses to run again once a `.runner` file exists, so without it
a `docker start` on this same container - which re-runs the full `docker run` command, not just `run.sh` - would fail
before `run.sh` ever started. With the guard, `docker start`/`docker stop` work as expected across restarts, since the
registration state lives in that container's writable layer. To pick up a newer image, register a fresh container from
the new tag (and deregister the old one) rather than trying to carry state over.

### Kubernetes with Actions Runner Controller (recommended)

For Kubernetes deployments, use the [Actions Runner Controller](https://github.com/actions/actions-runner-controller)
with container hooks, so each job step that specifies a container runs in its own ephemeral Pod instead of requiring a
Docker socket in the runner container. ARC's chart defaults assume the upstream image's `/home/runner` layout, so you
must override both the listener command and, for the dind template, the path its init container copies `externals` from
\- otherwise the runner container crash-loops on a path that doesn't exist in this image:

```yaml
template:
  spec:
    containers:
      - name: runner
        command: ["/usr/lib/actions-runner/run.sh"]
        env:
          - name: ACTIONS_RUNNER_CONTAINER_HOOKS
            value: /usr/share/gha-runner-container-hooks/k8s/index.js
```

If you use the `gha-runner-scale-set` dind template, also update its init container to copy from
`/usr/lib/actions-runner/externals` instead of the chart's default `/home/runner/externals`.

### Environment variables

| Variable                         | Description                                                           | Default | Required |
| -------------------------------- | --------------------------------------------------------------------- | ------- | -------- |
| `ACTIONS_RUNNER_CONTAINER_HOOKS` | Path to a hook script that intercepts container-action execution      | (unset) | No       |
| `RUNNER_MANUALLY_TRAP_SIG`       | Have `run.sh` install its own SIGINT/SIGTERM traps for clean shutdown | `1`     | No       |

## Non-hardened images vs. Docker Hardened Images

The upstream `ghcr.io/actions/actions-runner` image installs the runner directly into `/home/runner` and creates a
`runner` user with passwordless `sudo` and Docker group membership. This Docker Hardened Image installs the runner under
`/usr/lib/actions-runner` and runs as the standard DHI `nonroot` user (uid 65532) instead - the runner's registration
state and work directories still need to live alongside its binaries (this is an upstream constraint, not a DHI
convention), so that specific directory is owned by `nonroot` rather than being read-only. `sudo` is not included: the
image has no root entry in its user database, so a setuid-root `sudo` binary would not function anyway. Workflow steps
that need root-only operations should use a `dev` variant or a dedicated privileged step instead.

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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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

   For Debian-based images, you can use `apt-get` to install packages.

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
