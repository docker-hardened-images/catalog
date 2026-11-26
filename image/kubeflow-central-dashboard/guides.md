## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kubeflow-central-dashboard:<tag>`
- Mirrored image: `<your-namespace>/dhi-kubeflow-central-dashboard:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Kubeflow Central Dashboard is the web UI of a Kubeflow installation. It serves the UI and its API on port 8082, links
the component UIs listed in the `dashboard-config` ConfigMap, and shows each user's namespaces, activity and resources.
It reads the ConfigMap, namespaces, events and nodes through the Kubernetes API, and gets each user's workgroups from
the Kubeflow Access Management (KFAM) API. Configuration and development documentation is upstream at
https://github.com/kubeflow/dashboard/tree/main/components/centraldashboard.

`dhi.io/kubeflow-central-dashboard:2` is the Debian 13 runtime image and
`dhi.io/kubeflow-central-dashboard:2-alpine3.24` is the Alpine 3.24 one. Pin `2.0.1` or `2.0.1-alpine3.24` for a fixed
release. Use a runtime tag in a cluster. Dev tags run as root, so a pod with `runAsNonRoot: true` rejects them. FIPS
variants add `fips` to the tag, for example `dhi.io/kubeflow-central-dashboard:2-fips`.

## Start a Kubeflow Central Dashboard image

The entrypoint starts the server under `tini`, the same as upstream. Runtime tags run as user 1000, the `node` user of
the upstream image, and contain no shell.

### Basic usage

```bash
docker run -d --name kubeflow-central-dashboard -p 8082:8082 dhi.io/kubeflow-central-dashboard:2
curl --retry 30 --retry-all-errors --retry-delay 1 --retry-connrefused -fsS http://localhost:8082/healthz
```

The server takes a few seconds to start listening, so `curl` retries until it answers. The `Connection reset by peer`
lines it prints while it waits are expected.

`/healthz` answers `{"codeEnvironment":"production","message":"I tick, therfore I am!"}` and the UI is at
`http://localhost:8082/`. Outside a cluster the server has no Kubernetes API to talk to, so it logs
`Unable to fetch Nodes` errors and the namespace and activity panels stay empty, the same as the upstream image.
Prometheus metrics for the server itself are at `http://localhost:8082/prometheus/metrics`.

### Configure identity and backends

The dashboard does not authenticate users. It reads the user's identity from a request header that the authenticating
proxy in front of it sets. The code defaults expect Google Identity-Aware Proxy, and the Kubeflow manifests override
them for oauth2-proxy and Istio:

| Variable                     | Description                                                             | Default                           | Kubeflow manifests |
| ---------------------------- | ----------------------------------------------------------------------- | --------------------------------- | ------------------ |
| `USERID_HEADER`              | Request header that carries the user's identity                         | `X-Goog-Authenticated-User-Email` | `kubeflow-userid`  |
| `USERID_PREFIX`              | Prefix removed from the header value                                    | `accounts.google.com:`            | empty              |
| `PROFILES_KFAM_SERVICE_HOST` | Host of the KFAM API                                                    | `profiles-kfam.kubeflow`          | same               |
| `PROFILES_KFAM_SERVICE_PORT` | Port of the KFAM API                                                    | `8081`                            | same               |
| `REGISTRATION_FLOW`          | Lets a user without a profile create one from the UI                    | `true`                            | `false`            |
| `DASHBOARD_CONFIGMAP`        | ConfigMap in the dashboard's namespace with the menu links and settings | `dashboard-config`                | same               |
| `LOGOUT_URL`                 | Where the logout button sends the user                                  | `/logout`                         | `/oauth2/sign_out` |
| `COLLECT_METRICS`            | Serves the server's Prometheus metrics at `/prometheus/metrics`         | `true`                            | same               |
| `PORT_1`                     | Port the server listens on                                              | `8082`                            | not set            |
| `PROMETHEUS_URL`             | Prometheus endpoint for the cluster resource charts                     | not set                           | not set            |

The `/debug` endpoint shows the identity the dashboard resolved for a request, which is a quick way to check the header
settings. The first command removes the container from the previous example, which holds the same name and port:

```bash
docker rm -f kubeflow-central-dashboard
docker run -d --name kubeflow-central-dashboard -p 8082:8082 \
  -e USERID_HEADER=kubeflow-userid \
  -e USERID_PREFIX= \
  -e REGISTRATION_FLOW=false \
  dhi.io/kubeflow-central-dashboard:2
curl --retry 30 --retry-all-errors --retry-delay 1 --retry-connrefused -fsS \
  -H 'kubeflow-userid: user@example.com' http://localhost:8082/debug
```

The response contains `"email":"user@example.com"` and `"hasAuth":true`. When KFAM is unreachable, workgroup requests
such as `/api/workgroup/exists` answer `{"error":"Unable to contact Profile Controller"}`. Docker Hardened Images also
ships the KFAM server as `dhi.io/kubeflow-access-management`. Without `PROMETHEUS_URL`, the resource charts only work on
Google Kubernetes Engine, through Cloud Monitoring.

### Deploy with the Kubeflow manifests

The Kubeflow manifests deploy the dashboard as the `dashboard` Deployment in the `kubeflow` namespace, with its
ServiceAccount, RBAC, Service, `dashboard-config` ConfigMap and Istio routing. To run this image there, keep the
upstream overlay and replace the image. This kustomization uses the overlay that the Kubeflow 26.10.0 example
installation deploys, and adds an image pull secret for `dhi.io` to the ServiceAccount:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - https://github.com/kubeflow/manifests//applications/dashboard/upstream/centraldashboard/overlays/kserve?ref=26.10.0

images:
  - name: ghcr.io/kubeflow/dashboard/dashboard
    newName: dhi.io/kubeflow-central-dashboard
    newTag: 2.0.1

patches:
  - target:
      kind: ServiceAccount
      name: dashboard
    patch: |-
      - op: add
        path: /imagePullSecrets
        value:
          - name: dhi-pull-secret
```

Create the `dhi-pull-secret` docker-registry secret for `dhi.io` in the `kubeflow` namespace first. The upstream
Deployment's security context, `runAsNonRoot: true` and `runAsUser: 1000` with all capabilities dropped, matches the
image, and the server needs no writable path, so `readOnlyRootFilesystem: true` works without extra volumes. The
`/healthz` liveness and readiness probes on port 8082 are unchanged.

## Non-hardened images vs. Docker Hardened Images

The entrypoint is `/usr/bin/tini -- node dist/server.js`. Upstream runs `tini -- npm start`, which starts the same
`node dist/server.js` process through npm. Runtime images have no npm, npx, yarn, corepack or shell, so a `command:` or
`args:` override that calls `npm` fails. Call `node dist/server.js` from the `/usr/src/app` working directory instead.
The dev tags add bash, npm and the package manager.

`/usr/src/app` holds only the built server and UI (`dist`), `node_modules` and `package.json`, owned by root and
read-only for the runtime user. Upstream ships the whole source tree there, owned by the `node` user.

The FIPS variants run Node.js with the OpenSSL FIPS provider, so TLS connections the server makes, such as to the
Kubernetes API, go through the validated module. This command prints `1` on a FIPS tag:

```bash
docker run --rm --entrypoint node dhi.io/kubeflow-central-dashboard:2-fips -p 'crypto.getFips()'
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
