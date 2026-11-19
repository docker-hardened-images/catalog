## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this kubeflow-pipelines-inverse-proxy-agent image

This Docker Hardened kubeflow-pipelines-inverse-proxy-agent image includes:

- `proxy-forwarding-agent` — The inverting-proxy agent, which polls the proxy for requests and forwards them to the
  Kubeflow Pipelines UI service.
- `gcloud` — Google Cloud CLI, used by the launcher to activate a service account and mint access tokens.
- `kubectl` — Kubernetes CLI, used by the launcher to read and update the `inverse-proxy-config` ConfigMap.

The default command runs the upstream launcher, `/opt/proxy/attempt-register-vm-on-proxy.sh`. The launcher is a Bash
script, so unlike most hardened runtime images, the runtime variants include `bash`, `sh`, `curl`, `jq`, and `python3`.
They don't include a package manager.

## Start a kubeflow-pipelines-inverse-proxy-agent image

The launcher only works inside a Kubernetes pod running on Google Cloud. It needs the Kubernetes API, the Google Compute
Engine metadata server, and the Kubeflow Pipelines UI Service. Outside such a pod, the default command exits with an
error. To check the image locally, run the bundled tools directly:

```bash
docker run --rm --entrypoint /opt/bin/proxy-forwarding-agent \
  dhi.io/kubeflow-pipelines-inverse-proxy-agent:<tag> --help

docker run --rm --entrypoint kubectl \
  dhi.io/kubeflow-pipelines-inverse-proxy-agent:<tag> version --client

docker run --rm --entrypoint gcloud \
  dhi.io/kubeflow-pipelines-inverse-proxy-agent:<tag> --version
```

### How the launcher starts the agent

The launcher works with the `inverse-proxy-config` ConfigMap in the pod's own namespace:

1. If the ConfigMap already has a `Hostname` key, the launcher logs `Reuse existing hostname`, reads `ProxyUrl` and
   `BackendId` from the ConfigMap, and starts the agent. The UI keeps the same URL across pod restarts and image
   changes.
1. Otherwise, it registers a new backend with Google's inverting proxy. It reads the zone and the VM identity from the
   GCE metadata server (`metadata.google.internal`) and gets an access token with `gcloud`. It then writes `Hostname`,
   `ProxyUrl`, and `BackendId` to the ConfigMap and starts the agent.

In both cases, the agent forwards requests to `ML_PIPELINE_UI_SERVICE_HOST:ML_PIPELINE_UI_SERVICE_PORT`. Kubernetes sets
these variables in pods that start after the `ml-pipeline-ui` Service exists in the same namespace. The agent
authenticates to the proxy with Google Application Default Credentials: the node's metadata server credentials, or the
key file in `GOOGLE_APPLICATION_CREDENTIALS`.

When `PROXY_URL` isn't set, registration first downloads the list of proxy servers from
`https://storage.googleapis.com/ml-pipeline/proxy-agent-config.json`. At the time of writing, that URL returns HTTP 403,
so a new registration only succeeds when you set `PROXY_URL`. This is an upstream condition and affects the upstream
image in the same way. Installations that are already registered aren't affected, because they reuse the ConfigMap.

### Environment variables

| Variable                                                     | Description                                                                                                                                       | Default           | Required |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- | -------- |
| `PROXY_URL`                                                  | Inverting proxy URL to register with. Skips the proxy list download. Ignored when the ConfigMap already has a `Hostname`.                         | unset             | No       |
| `GOOGLE_APPLICATION_CREDENTIALS`                             | Path to a service account key file. The launcher activates it with `gcloud auth activate-service-account`, and the agent uses it to authenticate. | unset             | No       |
| `ML_PIPELINE_UI_SERVICE_HOST`, `ML_PIPELINE_UI_SERVICE_PORT` | Backend address of the Pipelines UI. Kubernetes sets these from the `ml-pipeline-ui` Service.                                                     | set by Kubernetes | Yes      |
| `DEBUG`                                                      | Enables agent debug logging.                                                                                                                      | `false`           | No       |
| `PROXY_TIMEOUT`                                              | Timeout for agent requests to the proxy.                                                                                                          | `60s`             | No       |
| `HEALTH_CHECK_PATH`                                          | Path on the UI backend for agent health checks.                                                                                                   | `/`               | No       |
| `HEALTH_CHECK_INTERVAL_SECONDS`                              | Seconds between health checks. `0` disables them.                                                                                                 | `0`               | No       |
| `HEALTH_CHECK_UNHEALTHY_THRESHOLD`                           | Consecutive failed checks before the backend is marked unhealthy.                                                                                 | `2`               | No       |

## Common kubeflow-pipelines-inverse-proxy-agent use cases

To pull the image in Kubernetes, first follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication). The
examples assume that Kubeflow Pipelines runs in the `kubeflow` namespace.

### Switch an existing Kubeflow Pipelines installation to the hardened image

The upstream Google Cloud manifests (`manifests/kustomize/env/gcp`) deploy the agent as the `proxy-agent` Deployment
with the `proxy-agent-runner` ServiceAccount. Add your pull secret to the ServiceAccount and replace the image. Use a
tag that matches your Kubeflow Pipelines version.

```bash
kubectl -n kubeflow patch serviceaccount proxy-agent-runner \
  -p '{"imagePullSecrets": [{"name": "<secret name>"}]}'
kubectl -n kubeflow set image deployment/proxy-agent \
  proxy-agent=dhi.io/kubeflow-pipelines-inverse-proxy-agent:<tag>
```

The upstream Deployment doesn't set a security context, so the agent runs as the image's nonroot user (UID 65532). The
new pod reuses the existing registration, and the UI URL doesn't change:

```bash
kubectl -n kubeflow logs deployment/proxy-agent | grep 'Reuse existing hostname'
kubectl -n kubeflow get configmap inverse-proxy-config -o jsonpath='{.data.Hostname}'
```

### Deploy the agent with a standalone manifest

The following manifest deploys the agent next to an existing `ml-pipeline-ui` Service. It keeps the upstream
`hostNetwork: true` setting, and sets the security context to the image's numeric user. The Role allows only `get` and
`patch` on the `inverse-proxy-config` ConfigMap, which is all the launcher uses. Upstream grants every verb on every
ConfigMap in the namespace.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: proxy-agent-runner
  namespace: kubeflow
imagePullSecrets:
  - name: <secret name>
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: proxy-agent-runner
  namespace: kubeflow
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["inverse-proxy-config"]
    verbs: ["get", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: proxy-agent-runner
  namespace: kubeflow
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: proxy-agent-runner
subjects:
  - kind: ServiceAccount
    name: proxy-agent-runner
    namespace: kubeflow
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: inverse-proxy-config
  namespace: kubeflow
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: proxy-agent
  namespace: kubeflow
  labels:
    app: proxy-agent
spec:
  selector:
    matchLabels:
      app: proxy-agent
  template:
    metadata:
      labels:
        app: proxy-agent
    spec:
      hostNetwork: true
      serviceAccountName: proxy-agent-runner
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
      containers:
        - name: proxy-agent
          image: dhi.io/kubeflow-pipelines-inverse-proxy-agent:<tag>
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
```

The container needs no `command` or `args`. The image's default command runs the launcher.

### Register with an explicit proxy URL

Because the default proxy list download fails, set `PROXY_URL` before the first registration:

```bash
kubectl -n kubeflow set env deployment/proxy-agent PROXY_URL=<inverting proxy URL>
```

The launcher ignores `PROXY_URL` while the ConfigMap holds a `Hostname`. To register again, clear the ConfigMap and
restart the agent. The new registration can return a different hostname, which changes the UI URL.

```bash
kubectl -n kubeflow patch configmap inverse-proxy-config --type json \
  -p '[{"op": "remove", "path": "/data"}]'
kubectl -n kubeflow rollout restart deployment/proxy-agent
```

## Non-hardened images vs. Docker Hardened Images

- **User:** The upstream image runs as root. The runtime variants run as `nonroot` (UID 65532). A key file mounted for
  `GOOGLE_APPLICATION_CREDENTIALS` must be readable by that user. `gcloud` keeps its state in
  `/home/nonroot/.config/gcloud` instead of `/root/.config/gcloud`.
- **Working directory:** `/opt/proxy` is owned by root. The launcher's only write there is the proxy list download to
  `/opt/proxy/proxy-agent-config.json`, which the nonroot user can write.
- **Platforms:** The upstream image is published for `linux/amd64` only. This image is published for `linux/amd64` and
  `linux/arm64`.

### FIPS variants

In the `-fips` and `-fips-dev` variants, `gcloud`, `curl`, and the launcher's Python helper use the system OpenSSL with
its FIPS provider. `proxy-forwarding-agent` and `kubectl` are built with the Go Cryptographic Module (FIPS 140-3). One
exception: with a service account key file in `GOOGLE_APPLICATION_CREDENTIALS`, `gcloud auth activate-service-account`
signs with gcloud's bundled pure-Python `rsa` library, which isn't a FIPS-validated module. In FIPS-bound environments,
use the node's metadata server credentials instead of a key file.

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
