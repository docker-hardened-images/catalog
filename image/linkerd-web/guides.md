## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/linkerd-web:<tag>`
- Mirrored image: `<your-namespace>/dhi-linkerd-web:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a linkerd-web image

Linkerd web is the viz dashboard. This image contains the dashboard binary and static assets. The entrypoint is `./web`,
the working directory is `/linkerd`, and the process runs as UID 65532. Dashboard HTTP is served on port 8084. The admin
server on port 9994 serves `/ping`, `/ready`, and `/metrics`.

The UI is described in the [Linkerd overview](https://linkerd.io/2/overview/). The dashboard is the `web` directory of
[linkerd2](https://github.com/linkerd/linkerd2).

### Check the packaged release

`./web -version` prints the Linkerd release stored in `LINKERD_CONTAINER_VERSION_OVERRIDE`. On this image that variable
is `edge-<release>`, the edge release the tag was built from:

```bash
$ docker run --rm dhi.io/linkerd-web:<tag> -version
edge-<release>
```

The HTML attribute `data-release-version` and `GET /api/version` read the `linkerdVersion` field of the `linkerd-config`
ConfigMap. A start that cannot read that ConfigMap leaves both empty.

### Use the image with the Linkerd viz Helm chart

Install the Linkerd control plane as described in the
[Linkerd installation guide](https://linkerd.io/2/getting-started/), then install the viz extension and point the
dashboard image at this image. The chart builds the reference from `dashboard.image.registry`, `dashboard.image.name`
(default `web`), and `dashboard.image.tag` (default `linkerdVersion`):

```bash
$ helm repo add linkerd https://helm.linkerd.io/edge
$ helm install linkerd-viz linkerd/linkerd-viz \
  --create-namespace --namespace linkerd-viz \
  --set dashboard.image.registry=dhi.io \
  --set dashboard.image.name=linkerd-web \
  --set dashboard.image.tag=<tag> \
  --set dashboard.UID=65532 \
  --set dashboard.GID=65532
```

Without `dashboard.image.tag` the chart uses its own Linkerd release version, for example `edge-<release>`, which is
also a tag of this image. Set `dashboard.image.name` to `linkerd-web`; the chart default is `web`. Add
`--set imagePullSecrets[0].name=<secret>` when the cluster pulls from `dhi.io` with a pull secret.

`dashboard.UID` and `dashboard.GID` are empty in the chart, and the web template falls back to `defaultUID` and
`defaultGID`, both 2103. Set them to 65532 so the dashboard container runs as the image user and group. The chart also
sets `readOnlyRootFilesystem`. In a manifest you write yourself, set `runAsUser` and `runAsGroup` to 65532.

## Common linkerd-web use cases

### Serve the dashboard files without a cluster

A full dashboard needs a cluster: the metrics API, and the `linkerd-config` ConfigMap. The process also needs a
Kubernetes client configuration. With none, it exits because no configuration has been provided.

A kubeconfig whose API server is `https://127.0.0.1:1` is enough for the process to stay up and serve the UI files. That
address refuses connections. Create the file mode `0644` so UID 65532 can read it. This only proves that the UI process
serves. `data-release-version` stays empty. The log includes `running version edge-<release>` and
`Failed to fetch linkerd-config`, and it warns that no cluster domain was passed and falls back to `cluster.local`.

```bash
$ mkdir -p /tmp/linkerd-web
$ cat > /tmp/linkerd-web/kubeconfig <<'EOF'
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: https://127.0.0.1:1
contexts:
- name: local
  context:
    cluster: local
    user: local
current-context: local
users:
- name: local
  user: {}
EOF
$ chmod 0644 /tmp/linkerd-web/kubeconfig
$ docker run -d --name linkerd-web \
  -p 8084:8084 -p 9994:9994 \
  -v /tmp/linkerd-web/kubeconfig:/kubeconfig:ro \
  dhi.io/linkerd-web:<tag> \
  --kubeconfig /kubeconfig
$ timeout 30 sh -c 'until curl -fsS http://127.0.0.1:9994/ping >/dev/null 2>&1; do sleep 1; done'
$ curl -fsS http://127.0.0.1:9994/ping
pong
$ curl -fsS http://127.0.0.1:8084/ | grep -o '/dist/index_bundle.js'
/dist/index_bundle.js
$ curl -fsS http://127.0.0.1:8084/api/version
{"version":""}
```

`GET /` returns HTML (`Content-Type: text/html`). The body contains `<div class="main" id="main"` and references
`/dist/index_bundle.js`. `GET /api/version` returns `{"version":""}`.

## Non-hardened images vs. Docker Hardened Images

- Tags carry the Linkerd release the image ships in, for example `edge-<release>`, and the release number, for example
  `<release>` without the `edge-` prefix. The upstream image is tagged with the Linkerd release only. The `26` tag moves
  to each new edge release of 2026 and the `26.<minor>` tag to each edge release of that minor line. Upstream edge
  releases can include breaking changes, so pin `edge-<release>` or `<release>` to stay on one release.
- The image runs as the nonroot user, UID and GID 65532. The upstream image user is root unless the pod sets a user. Set
  the viz chart `dashboard.UID` and `dashboard.GID` to 65532. Left empty, the chart falls back to 2103.
- `LINKERD_CONTAINER_VERSION_OVERRIDE` is set to the Linkerd release, and `-version` prints it. The UI release fields
  come from the `linkerd-config` ConfigMap.
- The runtime variants contain no shell. Use the dev variants, or Docker Debug, to get one.

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
