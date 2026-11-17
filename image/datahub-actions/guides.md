## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About this image

This Docker Hardened DataHub Actions image provides the `datahub-actions` event-driven framework in three upstream
variants:

#### Slim variant (default)

Equivalent to the upstream `acryldata/datahub-actions:<version>-slim` tag. Installs `acryl-datahub-actions[all]` — the
full set of pluggable actions (executor, slack, teams, doc/tag/term propagation) running against the standard Kafka
event source. Suitable for the majority of Actions deployments where ingestion runs in a separate
`dhi/datahub-ingestion` container or pod.

#### Locked variant (`-locked`)

Hardened for airgap and regulated environments. Installs the minimal `base` extra at build time and sets `UV_INDEX_URL`
and `PIP_INDEX_URL` to an unreachable endpoint, so the image cannot reach PyPI at runtime. Use this variant when your
deployment policy prohibits unaudited runtime package installation.

### Runtime dependency on DataHub GMS

The image entrypoint is a bash script (`/opt/datahub/scripts/start.sh`) that polls the DataHub GMS `/health` endpoint on
container boot and waits up to 240 s for it to return 200 before starting the actions framework. **The Actions container
will not progress past startup until GMS is reachable.**

Configure the GMS endpoint via env vars:

| Variable                          | Default       | Purpose                                                 |
| :-------------------------------- | :------------ | :------------------------------------------------------ |
| `DATAHUB_GMS_HOST`                | `datahub-gms` | DNS name or IP of the GMS service                       |
| `DATAHUB_GMS_PORT`                | `8080`        | GMS HTTP port                                           |
| `DATAHUB_GMS_PROTOCOL`            | `http`        | `http` or `https`                                       |
| `DATAHUB_GMS_STARTUP_TIMEOUT_SEC` | `240`         | How long start.sh waits for GMS before exiting non-zero |

A minimal multi-container example using the sibling hardened GMS image:

```console
$ docker network create datahub
$ docker run -d --rm --name datahub-gms --network datahub \
    dhi.io/datahub-gms:1
$ docker run --rm --name datahub-actions --network datahub \
    -v "$(pwd)/my-action.yaml:/etc/datahub/actions/conf/my-action.yaml:ro" \
    -e DATAHUB_GMS_HOST=datahub-gms \
    dhi.io/datahub-actions:1
```

The container runs as the `nonroot` user (uid 65532); ensure mounted action configs and credential files are readable by
that user.

### Mounting custom action configurations

The runtime scans two directories for YAML pipeline configs and passes every file in them as a `-c <file>` argument to
`datahub-actions actions`:

- **System actions** (shipped with the image):
  `/etc/datahub/actions/system/conf/{executor,doc_propagation_action,slack_action,teams_action}.yaml`
- **User actions** (you mount these): `/etc/datahub/actions/conf/*.{yaml,yml}`

To add a custom action, write a YAML pipeline file and bind-mount it into the user config dir:

```console
$ docker run --rm \
  --network datahub \
  -v /path/to/my-action.yaml:/etc/datahub/actions/conf/my-action.yaml:ro \
  -e DATAHUB_GMS_HOST=datahub-gms \
  dhi.io/datahub-actions:<tag>
```

To disable a system action without modifying the image, mount an empty file over it:

```console
$ docker run --rm \
  -v /dev/null:/etc/datahub/actions/system/conf/slack_action.yaml:ro \
  …
```

For the action pipeline schema and source-specific configuration options, see the
[upstream actions docs](https://docs.datahub.com/docs/actions/concepts).

### Quick test: list registered actions

To inspect available action plugins without starting the GMS-dependent wait loop, override the entrypoint:

```console
$ docker run --rm --entrypoint /opt/datahub/bin/datahub-actions \
    dhi.io/datahub-actions:<tag> actions --help
```

To check the version:

```console
$ docker run --rm --entrypoint /opt/datahub/bin/datahub-actions \
    dhi.io/datahub-actions:<tag> --version
```

### Optional monitoring HTTP server

Set `DATAHUB_ACTIONS_MONITORING_ENABLED=true` and (optionally) `DATAHUB_ACTIONS_MONITORING_PORT=<port>` (default 8000)
to enable the built-in Prometheus-style monitoring HTTP server. Expose the port on the container if you want to scrape
it:

```console
$ docker run --rm \
  -e DATAHUB_ACTIONS_MONITORING_ENABLED=true \
  -p 8000:8000 \
  …
```

### Deviation from upstream: no per-plugin bundled venvs

Upstream pre-builds isolated Python venvs under `/opt/datahub/venvs/<plugin>/` for the `executor` action's subprocess
plugins. This DHI image collapses everything into the single `/opt/datahub` venv — every dependency is resolved once at
build time. If your custom action invokes a subprocess and assumes the upstream
`${DATAHUB_BUNDLED_VENV_PATH}/<plugin>/bin/python` layout, update it to invoke `/opt/python/bin/python` instead.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  Note: this image's runtime variants do contain `bash`, `coreutils`, and `curl` — these are required by the vendored
  entrypoint script that waits for GMS before starting the actions framework. The runtime still does not contain a
  package manager.

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                            |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The upstream `acryldata/datahub-actions` image runs as the `datahub` user (uid 1000) with `HOME=/home/datahub`. The
Docker Hardened Image runs as the nonroot user (uid 65532) with `HOME=/home/nonroot`. Any volume mounts that target
upstream's user-home paths (e.g. `/home/datahub/.aws-ro/sso/cache`) must be retargeted to `/home/nonroot/...` instead.
The vendored entrypoint script has been adjusted accordingly.

## Troubleshooting migration

### Container exits with "Timeout waiting for GMS at http://datahub-gms:8080/health"

The container could not reach GMS within `DATAHUB_GMS_STARTUP_TIMEOUT_SEC` seconds (default 240). Verify:

1. GMS is running and the `/health` endpoint returns HTTP 200.
1. The Actions container shares a network with GMS (same Docker network, same k8s service).
1. `DATAHUB_GMS_HOST` matches the GMS DNS name or IP. The default is `datahub-gms`, which works if the GMS container has
   that network alias.

For airgap or initial-bringup deployments, bump `DATAHUB_GMS_STARTUP_TIMEOUT_SEC` rather than altering startup ordering.

### Locked variant: PyPI access blocked

The locked variant intentionally blocks PyPI by setting `UV_INDEX_URL` and `PIP_INDEX_URL` to an unreachable endpoint.
If a custom action attempts a runtime install via `uv` or `pip`, you'll see `Connection refused` or
`Name or service not known`. Either bake the package into a custom image with the dev variant, or switch to the slim
variant.

### General debugging

The runtime images contain `bash`, `coreutils`, and `curl` (required by the entrypoint script), but do not include a
package manager or broader debugging tooling. For more thorough debugging use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to running containers.

### Permissions

By default image variants intended for runtime run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

If you mount action configs or credential files, ensure they are readable by uid 65532.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
