## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/opencost-ui:<tag>`
- Mirrored image: `<your-namespace>/dhi-opencost-ui:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About this opencost-ui Hardened Image

This image contains the OpenCost UI — a React single-page application served by nginx. It is designed to run alongside
the [OpenCost](https://opencost.io) model API, which it proxies for cost data. The UI resolves configuration at startup:
the entrypoint script replaces placeholder values baked into the JavaScript bundles and generates an nginx server block
from a template using `envsubst`, so all runtime behavior is controlled through environment variables rather than
rebuilding the image.

The container listens on `9090/tcp` by default and serves the UI at `UI_PATH` (default `/`), proxying requests to
`BASE_URL` (default `/model`) to the OpenCost cost-model API at `API_SERVER:API_PORT`.

## Start an opencost-ui container

OpenCost UI requires a running OpenCost cost-model API to display cost data, but it will start and serve the static
frontend independently. The API connection is only needed when the browser loads and fetches cost data.

### Basic usage

```bash
docker run -d --name opencost-ui -p 9090:9090 \
  -e API_SERVER=<opencost-model-host> \
  -e API_PORT=9003 \
  dhi.io/opencost-ui:<tag>
```

Open `http://localhost:9090` in your browser to access the OpenCost dashboard.

### Entrypoint and ports

- The entrypoint is `/usr/local/bin/docker-entrypoint.sh`, which performs JS placeholder substitution and nginx config
  generation, then execs `nginx -g 'daemon off;'`.
- The UI listens on `9090/tcp` by default (controlled by `UI_PORT`).
- The API proxy is served at `/model/` by default (controlled by `BASE_URL`).
- A liveness probe endpoint is available at `/healthz` (returns `200 OK`).

## Environment variables

All runtime configuration is via environment variables. The entrypoint applies defaults for any unset variable so the
container starts cleanly without explicit configuration.

### Core settings

| Environment variable | Description                                           | Default |
| -------------------- | ----------------------------------------------------- | ------- |
| `UI_PORT`            | Port nginx listens on inside the container            | `9090`  |
| `UI_PATH`            | URL path prefix for the UI (use `/` for root)         | `/`     |
| `LEGACY_MODE`        | Serve the legacy UI build instead of the standard one | `false` |

### API proxy settings

| Environment variable | Description                                         | Default   |
| -------------------- | --------------------------------------------------- | --------- |
| `API_SERVER`         | Hostname or IP of the OpenCost cost-model API       | `0.0.0.0` |
| `API_PORT`           | Port of the OpenCost cost-model API                 | `9003`    |
| `BASE_URL`           | URL prefix proxied to the cost-model API            | `/model`  |
| `BASE_URL_OVERRIDE`  | Override `BASE_URL` in the UI JS bundles at startup |           |

### Proxy timeout settings

| Environment variable    | Description                    | Default |
| ----------------------- | ------------------------------ | ------- |
| `PROXY_CONNECT_TIMEOUT` | nginx proxy connection timeout | `60s`   |
| `PROXY_SEND_TIMEOUT`    | nginx proxy send timeout       | `60s`   |
| `PROXY_READ_TIMEOUT`    | nginx proxy read timeout       | `60s`   |

### UI customisation settings

| Environment variable         | Description                                                               |
| ---------------------------- | ------------------------------------------------------------------------- |
| `OPENCOST_FOOTER_CONTENT`    | Custom footer text injected into UI bundles at startup                    |
| `CUSTOM_AGGREGATION_OPTIONS` | JSON map of custom cost aggregation labels (e.g. `{"Team":"label:team"}`) |
| `VERSION`                    | OpenCost version string shown in the footer                               |
| `HEAD`                       | Git commit SHA shown in the footer                                        |

## Common use cases

### Install OpenCost with Helm

You can deploy OpenCost with the official Helm chart and override the UI image. Replace `<your-registry-secret>` with
your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>` with the desired image tag.

```bash
helm repo add opencost https://opencost.github.io/opencost-helm-chart
helm repo update

helm upgrade --install opencost opencost/opencost \
  --namespace opencost \
  --create-namespace \
  --set "imagePullSecrets[0].name=<your-registry-secret>" \
  --set opencost.ui.image.repository=dhi.io/opencost-ui \
  --set opencost.ui.image.tag=<tag>
```

### Enable legacy UI mode

OpenCost UI ships two builds: the default React Router 7 build and a legacy build for environments that require the
older UI. To activate the legacy build, set `LEGACY_MODE=true`:

```bash
docker run -d --name opencost-ui -p 9090:9090 \
  -e API_SERVER=<opencost-model-host> \
  -e LEGACY_MODE=true \
  dhi.io/opencost-ui:<tag>
```

### Serve the UI at a subpath

If OpenCost UI is reverse-proxied behind a path prefix (for example `/opencost`), set `UI_PATH` to match:

```bash
docker run -d --name opencost-ui -p 9090:9090 \
  -e API_SERVER=<opencost-model-host> \
  -e UI_PATH=/opencost/ \
  dhi.io/opencost-ui:<tag>
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened OpenCost UI       | Docker Hardened OpenCost UI                         |
| --------------- | ------------------------------ | --------------------------------------------------- |
| Security        | Standard Alpine base           | Minimal, hardened Debian base with security patches |
| Shell access    | Full shell available           | Shell present (required by entrypoint)              |
| Package manager | apk available                  | No package manager in runtime variants              |
| User            | Runs as UID 1001               | Runs as nginx user (UID 65532)                      |
| Attack surface  | Larger due to Alpine utilities | Minimal, only essential components                  |
| Debugging       | Traditional shell              | Use Docker Debug for troubleshooting                |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a package manager
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

Switching to the hardened OpenCost UI image requires only an image reference change. The entrypoint, environment
variables, and port are identical to the upstream `ghcr.io/opencost/opencost-ui` image.

### Migration steps

1. Replace the image reference in your Deployment, Helm values, or Compose file with `dhi.io/opencost-ui:<tag>`.

1. All existing environment variables (`API_SERVER`, `API_PORT`, `BASE_URL`, `LEGACY_MODE`, etc.), port mappings, and
   volume mounts remain unchanged.

1. Update the run-as user if your manifests hard-code UID `1001` (the upstream user). The hardened image runs as UID
   `65532`. Set `securityContext.runAsUser: 65532` and `securityContext.runAsGroup: 65532` in your Kubernetes pod spec.

1. Test your migration and use the troubleshooting tips below if you encounter any issues.

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a package manager or debugging tools beyond the shell required by
the entrypoint. The recommended method for debugging is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers. Docker Debug provides a
shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists during
the debugging session.

### Permissions

By default, the runtime image runs as UID `65532` (nginx). If your deployment mounts volumes or config maps into the
container, ensure that the files are readable by this user. The directories `/var/www`, `/var/www/legacy`,
`/var/cache/nginx`, and `/run/nginx` are already owned by UID `65532` in the image.

### User ID mismatch

The upstream OpenCost UI image runs as UID `1001`. If your Kubernetes manifests or Helm values set
`securityContext.runAsUser: 1001`, update them to `65532` when switching to this hardened image.

### Entry point

The hardened image uses the same entrypoint script (`/usr/local/bin/docker-entrypoint.sh`) and `CMD`
(`nginx -g 'daemon off;'`) as the upstream image. If you override the command in your deployment, ensure the entrypoint
script still runs first so that JS placeholder substitution and nginx config generation are performed before nginx
starts.

### nginx config not generated

If nginx fails to start with a message about a missing `default.conf`, the entrypoint script may not have been able to
write to `/etc/nginx/conf.d/`. The entrypoint also rewrites JS assets under `/var/www` at startup, so this image needs a
writable root filesystem; if you run it with a read-only root filesystem, mount writable volumes over
`/etc/nginx/conf.d` and `/var/www`.
