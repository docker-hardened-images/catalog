## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this atlantis image

This Docker Hardened Atlantis image includes:

- `atlantis` — the Atlantis server binary
- `terraform` — a hardened Terraform build (from the Docker Hardened Terraform package) that Atlantis shells out to for
  `plan` and `apply` operations, on the 1.16 line that upstream Atlantis defaults to
- `git` and `git-lfs` — for cloning and updating pull request branches
- `openssh-client` — for cloning repositories over SSH
- GnuPG (`gpg`) — for verifying GPG-signed commits and tags

The image runs as the nonroot user and does not include OpenTofu (`tofu`) or `conftest`, both of which upstream Atlantis
images bundle. See [Non-hardened images vs Docker Hardened Images](#non-hardened-images-vs-docker-hardened-images) for
details.

### Run the atlantis container

Check the Atlantis version built into the image:

```console
$ docker run --rm dhi.io/atlantis:<tag> version
```

Print server flag help:

```console
$ docker run --rm dhi.io/atlantis:<tag> server --help
```

### Start the Atlantis server

Atlantis needs credentials for your VCS provider, a webhook secret, and a repository allowlist before it will accept
pull request events. The following example configures Atlantis for GitHub:

```console
$ docker run -d --name atlantis \
  -p 127.0.0.1:4141:4141 \
  -v atlantis-data:/home/nonroot/.atlantis \
  -e ATLANTIS_GH_USER=<github-username> \
  -e ATLANTIS_GH_TOKEN=<github-personal-access-token> \
  -e ATLANTIS_GH_WEBHOOK_SECRET=<webhook-secret> \
  -e ATLANTIS_REPO_ALLOWLIST='github.com/my-org/*' \
  -e ATLANTIS_ATLANTIS_URL=https://atlantis.example.com \
  dhi.io/atlantis:<tag>
```

Port 4141 serves the Atlantis web UI as well as the webhook endpoint, and that UI has no authentication unless you set
`--web-basic-auth` (`ATLANTIS_WEB_BASIC_AUTH`). The example binds the port to `127.0.0.1` so only the reverse proxy that
terminates TLS and forwards webhooks can reach it. Expose it more widely only once you have enabled basic auth or put
your own authentication in front.

The volume keeps the data directory across restarts. Without it, pull request locks and saved plans are lost whenever
the container is recreated.

The container's default command is `server`, so you don't need to specify it explicitly. Point your GitHub webhook at
`<ATLANTIS_ATLANTIS_URL>/events`, and Atlantis starts commenting `terraform plan` and `apply` output on your pull
requests.

Check that the server is healthy:

```console
$ curl http://localhost:4141/healthz
```

For the full list of server flags and their environment variable equivalents (for other VCS providers, TLS, policy
checks, and more) see the upstream
[server configuration reference](https://www.runatlantis.io/docs/server-configuration.html).

### Persist Atlantis data

Atlantis stores its database, checked-out repositories, Terraform plans, and downloaded Terraform binaries in
`--data-dir`, which defaults to `~/.atlantis`. In this image, `HOME` is set to `/home/nonroot`, so the data directory
resolves to `/home/nonroot/.atlantis`. Mount a volume there to persist state (including pull request locks) across
container restarts:

```console
$ docker run -d --name atlantis \
  -p 127.0.0.1:4141:4141 \
  -v atlantis-data:/home/nonroot/.atlantis \
  -e ATLANTIS_GH_USER=<github-username> \
  -e ATLANTIS_GH_TOKEN=<github-personal-access-token> \
  -e ATLANTIS_GH_WEBHOOK_SECRET=<webhook-secret> \
  -e ATLANTIS_REPO_ALLOWLIST='github.com/my-org/*' \
  -e ATLANTIS_ATLANTIS_URL=https://atlantis.example.com \
  dhi.io/atlantis:<tag>
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature            | Upstream Atlantis image                                                                        | Docker Hardened Atlantis                                                                                                                                                                                                           |
| ------------------ | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Entry point        | `docker-entrypoint.sh` shell wrapper that re-execs the binary under `dumb-init --single-child` | `dumb-init --single-child -- /usr/local/bin/atlantis` runs the binary directly; default `cmd` is still `server`. The wrapper's `/docker-entrypoint.d/*.sh` hooks and its `/etc/passwd` entry for arbitrary UIDs are not reproduced |
| Terraform tooling  | Bundles Terraform, OpenTofu (`tofu`), and `conftest`                                           | Bundles a hardened Terraform build only; no `tofu` or `conftest`                                                                                                                                                                   |
| Terraform download | Downloads a matching Terraform at runtime when a repo pins a different `required_version`      | `ATLANTIS_TF_DOWNLOAD` is set to `false`, so the image only ever runs the hardened build it ships. Set it to `true` to restore the upstream behaviour, which fetches the pinned version from releases.hashicorp.com at runtime     |
| Shell              | Full shell available                                                                           | Minimal `/bin/sh` (dash on Debian, busybox on Alpine) and coreutils, kept so custom workflow `run:` steps and pre/post-workflow hooks work                                                                                         |
| User               | Runs as `atlantis`, UID 100, GID 1000, with data in `/home/atlantis/.atlantis`                 | Runs as UID 65532 with data in `/home/nonroot/.atlantis`. Re-own existing data to 65532 (or set `fsGroup: 65532`), and set `--data-dir` explicitly if you need the old path                                                        |
| Health check       | Declares a `HEALTHCHECK` that runs `curl -f http://localhost:4141/healthz`                     | No `HEALTHCHECK`; the runtime image ships no `curl`. Probe `/healthz` from your orchestrator instead                                                                                                                               |

### Entry point

The hardened image drops the upstream `docker-entrypoint.sh` wrapper and runs the `atlantis` binary directly under
`dumb-init`, which still reaps the `terraform` and `git` subprocesses that Atlantis spawns. If your existing workflow
invokes the image with `server <flags>` (the common case), no change is needed:

```console
$ docker run --rm dhi.io/atlantis:<tag> server --repo-allowlist='github.com/my-org/*' --gh-user=<user> --gh-token=<token>
```

If you relied on other implicit behavior from upstream's shell wrapper (for example, sourcing a custom
`docker-entrypoint.sh` you mounted over the original), you must reimplement that logic outside the container, since this
image runs the binary directly. The runtime variant does ship `/bin/sh`, so a mounted wrapper can still be run by
overriding the entrypoint, but nothing sources one for you.

### OpenTofu and Conftest

Upstream Atlantis images bundle OpenTofu (`tofu`) and `conftest` alongside Terraform so that repos configured with
`--default-tf-distribution=opentofu` or with policy checks (`--enable-policy-checks`) work out of the box. This hardened
image does **not** include `tofu` or `conftest`. If your repositories depend on either tool:

- Use a `-dev` variant as a build stage to download the upstream `tofu`/`conftest` release binaries, then copy them into
  your own image built `FROM dhi.io/atlantis:<tag>`. There is no hardened package for either tool, so the binaries stay
  unhardened and you keep them up to date yourself.
- Or run OpenTofu/Conftest processing outside of Atlantis (for example, in a separate CI step) before Atlantis plans or
  applies.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

For example, usage of MD5 fails in FIPS variants. To verify FIPS compliance, check the cryptographic module version in
use by your Atlantis instance.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                 |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                      |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                      |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                     |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                         |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                             |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Atlantis's default port (4141) works without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                    |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                    |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

## Troubleshooting migration

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
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
