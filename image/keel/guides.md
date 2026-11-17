## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/keel:<tag>`
- Mirrored image: `<your-namespace>/dhi-keel:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Keel is a Kubernetes operator. The examples run the container with a kubeconfig file so you can exercise the HTTP API
without a full deployment. In a cluster, run keel with a ServiceAccount instead and grant it the
[RBAC rules](#kubernetes-rbac).

## Start a Keel image

Keel serves its API and web UI on port `9300/tcp`. Keel only updates workloads that carry the `keel.sh/policy`
annotation or label, so a container started without any opted-in workloads changes nothing in your cluster.

Check the version. Keel prints the version to stderr, so merge stderr into stdout and show the last line:

```bash
docker run --rm dhi.io/keel:<tag> --version 2>&1 | tail -n 1
```

Start keel with a kubeconfig for your cluster. The file must be readable by UID 65532, for example with `chmod 0644`:

```bash
docker run -d --name keel -p 127.0.0.1:9300:9300 \
  -v "$PWD/kubeconfig:/keel/kubeconfig:ro" \
  dhi.io/keel:<tag> --no-incluster --kubeconfig=/keel/kubeconfig
```

Check that the server is up:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9300/healthz
```

`GET /healthz` returns `200`. `GET /version` returns the version and build revision as JSON.

### Environment variables

| Variable              | Description                                                                                                                     | Default | Required                   |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------- | -------------------------- |
| `BASIC_AUTH_USER`     | Username for the web UI and audit API. The web UI is served only when `BASIC_AUTH_USER` and `BASIC_AUTH_PASSWORD` are both set. | unset   | No                         |
| `BASIC_AUTH_PASSWORD` | Password for `BASIC_AUTH_USER`.                                                                                                 | unset   | No                         |
| `HELM3_PROVIDER`      | Set to `true` to enable the Helm 3 provider.                                                                                    | unset   | No                         |
| `KUBECONFIG`          | Kubeconfig the Helm 3 provider reads. `--kubeconfig` does not set it for this provider.                                         | unset   | Yes, with `HELM3_PROVIDER` |
| `GODEBUG`             | Go runtime FIPS posture for FIPS variants. See [FIPS variants](#fips-variants).                                                 | unset   | No                         |

The image sets `HOME` and `XDG_DATA_HOME` to `/data`, so keel keeps its state there.

## Common Keel use cases

### Persist state in /data

Keel stores its SQLite database at `/data/keel.db`. `/data` is owned by UID and GID 65532, and that owner can write to
it. Mount a named volume there so state survives container restarts:

```bash
docker run -d --name keel -p 127.0.0.1:9300:9300 \
  -v keel-data:/data \
  -v "$PWD/kubeconfig:/keel/kubeconfig:ro" \
  dhi.io/keel:<tag> --no-incluster --kubeconfig=/keel/kubeconfig
```

A new named volume takes its owner from the image. A host bind mount keeps the host owner. If you bind-mount a host
directory, make it writable by UID 65532 first:

```bash
docker run --rm -v "$PWD/keel-data:/data" --entrypoint /bin/sh dhi.io/keel:<tag>-dev -c 'chown -R 65532:65532 /data'
```

Without this, keel logs `can't reach DB, waiting` and keeps retrying.

### Web UI and audit API

The web UI is served only when both `BASIC_AUTH_USER` and `BASIC_AUTH_PASSWORD` are set. Without them, `GET /` returns
`404`.

```bash
docker run -d --name keel -p 127.0.0.1:9300:9300 \
  -e BASIC_AUTH_USER=admin \
  -e BASIC_AUTH_PASSWORD='change-me' \
  -v "$PWD/kubeconfig:/keel/kubeconfig:ro" \
  dhi.io/keel:<tag> --no-incluster --kubeconfig=/keel/kubeconfig
```

With basic auth set, `GET /` returns the UI shell without credentials. The audit API requires them:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' 'http://127.0.0.1:9300/v1/audit?filter=deployment'
curl -sS -u admin:change-me 'http://127.0.0.1:9300/v1/audit?filter=deployment'
```

The first command returns `401`. `GET /v1/audit` returns an empty list without a `filter`, so pass a resource kind such
as `filter=deployment`.

`POST /v1/auth/login` with JSON `{"username":"admin","password":"change-me"}` returns a JSON object with a `token`
field.

### Native webhook

Post an image repository and new tag to trigger updates:

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  -d '{"name":"registry.example/keel-probe/app","tag":"1.0.1"}' \
  -w '%{http_code}\n' http://127.0.0.1:9300/v1/webhooks/native
```

The response is `200` with an empty body. `name` is the image repository without a tag. It must match the image in the
workload's pod template. A request without `name` returns `400`.

### Policy annotation

Opt a workload in with the `keel.sh/policy` key, set either as an annotation or as a label on the workload's `metadata`.
Keel only updates Deployments, StatefulSets, and DaemonSets that carry the key:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keel-probe
  namespace: default
  annotations:
    keel.sh/policy: all
spec:
  replicas: 0
  selector:
    matchLabels:
      app: keel-probe
  template:
    metadata:
      labels:
        app: keel-probe
    spec:
      containers:
      - name: app
        image: registry.example/keel-probe/app:1.0.0
```

With `keel.sh/policy: all`, a webhook for `registry.example/keel-probe/app:1.0.1` moves the Deployment to that tag. Keel
then writes `keel.sh/update-time` on the pod template. A Deployment without the policy key keeps its tag.

The same key works as a label. Use this form when your tooling manages labels rather than annotations. The example below
is the annotation form with the key moved to `metadata.labels`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keel-probe
  namespace: default
  labels:
    keel.sh/policy: all
spec:
  replicas: 0
  selector:
    matchLabels:
      app: keel-probe
  template:
    metadata:
      labels:
        app: keel-probe
    spec:
      containers:
      - name: app
        image: registry.example/keel-probe/app:1.0.0
```

The label form moves the Deployment exactly as the annotation form does. Other policy values are described in the
[upstream documentation](https://github.com/keel-hq/keel).

### Kubernetes RBAC

The native provider updates workloads through the Kubernetes API. Create this ClusterRole for it:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: keel
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["cronjobs"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps", "secrets", "pods", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch", "update"]
```

Bind the ClusterRole to the ServiceAccount that runs keel. This example assumes keel runs as `keel` in `keel-system`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: keel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: keel
subjects:
- kind: ServiceAccount
  name: keel
  namespace: keel-system
```

- Without `nodes` read, keel logs that workload updates are blocked because platform compatibility cannot be verified.
  Grant the rule; do not rely on updates continuing without it.
- Without `batch` `cronjobs` read, keel's informer fails with `cronjobs.batch is forbidden`.

If you deploy keel with the upstream Helm chart, point the chart's image repository and tag at this image, and make sure
the chart's ClusterRole includes the rules above. Run the pod as UID 65532 rather than copying an upstream security
context that runs as UID 666.

### Helm 3 provider

Enable the Helm 3 provider with `HELM3_PROVIDER=true` and set `KUBECONFIG` to the kubeconfig path:

```bash
docker run -d --name keel -p 127.0.0.1:9300:9300 \
  -e HELM3_PROVIDER=true \
  -e KUBECONFIG=/keel/kubeconfig \
  -v "$PWD/kubeconfig:/keel/kubeconfig:ro" \
  dhi.io/keel:<tag> --no-incluster --kubeconfig=/keel/kubeconfig
```

Without `KUBECONFIG`, the Helm 3 provider falls back to `localhost:8080` and logs `Kubernetes cluster unreachable`.

The Helm 3 provider also needs write access to its release storage. The native rules above do not grant it. See
[Release storage](#release-storage).

#### Release storage

Helm 3 keeps each revision of a release in a Secret in the release's namespace, and it applies the chart's objects with
the same ServiceAccount. Without write access to those Secrets, an upgrade fails with `secrets is forbidden`, keel
exits, and the release stays at its first revision. Grant access in each namespace where keel manages a Helm release.
This example covers a release in `default` whose chart renders a Deployment:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: keel-helm-releases
  namespace: default
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: keel-helm-releases
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: keel-helm-releases
subjects:
- kind: ServiceAccount
  name: keel
  namespace: keel-system
```

Add a rule for each other kind your chart renders, with the verbs its upgrades need.

### Moving data from the upstream image (UID 666)

Upstream keel runs as UID 666, and its `/data` is owned by 666. This image runs as 65532. A `/data` volume written by
upstream fails to open the database:

```text
level=warning msg="sql store connector: can't reach DB, waiting" error="unable to open database file: permission denied" uri=/data/keel.db
```

Change the ownership once, before the first start:

```bash
docker run --rm -v keel-data:/data --entrypoint /bin/sh dhi.io/keel:<tag>-dev -c 'chown -R 65532:65532 /data'
```

In Kubernetes, run the same command in an init container that runs as root, then start keel as 65532. The pod runs in
`keel-system` as the `keel` ServiceAccount, so it gets the RBAC from [Kubernetes RBAC](#kubernetes-rbac). Keep that
binding in place, or use the ServiceAccount that already holds it:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: keel
  namespace: keel-system
spec:
  serviceAccountName: keel
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
  initContainers:
  - name: fix-data-ownership
    image: dhi.io/keel:<tag>-dev
    securityContext:
      runAsUser: 0
      runAsNonRoot: false
    command: ["/bin/sh", "-c", "chown -R 65532:65532 /data"]
    volumeMounts:
    - name: data
      mountPath: /data
  containers:
  - name: keel
    image: dhi.io/keel:<tag>
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: keel-data
```

Setting `fsGroup: 65532` does not change the owner or group of an existing `keel.db` on a local-path PersistentVolume.
Use the init container instead.

### Shell access with the dev variant

Runtime images have no shell. The `-dev` variant runs as root and includes a shell and the distro's package manager. On
a Debian tag, the package manager is `apt-get`:

```bash
docker run --rm --entrypoint /bin/sh dhi.io/keel:<debian-tag>-dev -c 'id -u && command -v apt-get'
```

On an Alpine tag, it is `apk`:

```bash
docker run --rm --entrypoint /bin/sh dhi.io/keel:<alpine-tag>-dev -c 'id -u && command -v apk'
```

### FIPS variants

FIPS variants of this image contain keel built with the Go FIPS 140 module and the OpenSSL FIPS provider. The image sets
`OPENSSL_CONF` and `OPENSSL_MODULES` for OpenSSL. Use a FIPS tag, such as `dhi.io/keel:<tag>-fips` or
`dhi.io/keel:<tag>-fips-dev`, to get these.

To check the OpenSSL FIPS provider, list the providers in a FIPS dev image:

```bash
docker run --rm --entrypoint /bin/sh dhi.io/keel:<tag>-fips-dev -c 'openssl list -providers'
```

The `fips` provider reports `status: active`. A non-approved digest is refused:

```bash
docker run --rm --entrypoint /bin/sh dhi.io/keel:<tag>-fips-dev -c 'openssl dgst -md5 /etc/hostname'
```

This command fails with `unsupported` and exits non-zero.

To check that keel is linked with the versioned Go FIPS module:

```bash
docker run --rm --entrypoint /bin/sh dhi.io/keel:<tag>-fips-dev -c 'grep -a -c crypto/internal/fips140/v1.0.0 /usr/bin/keel'
```

The count is greater than zero. To run keel under strict Go FIPS enforcement, set `GODEBUG=fips140=only`. Keel starts
and answers `/healthz` with that setting. `only` can make non-approved crypto calls fail, so test your cluster
connections before you use it in production.

## Non-hardened images vs. Docker Hardened Images

Upstream `ghcr.io/keel-hq/keel` runs as UID 666 and its `/data` is owned by 666 with group 0. This image runs as UID and
GID 65532, and `/data` is owned by 65532 and writable by that owner. A `/data` directory left by the upstream image
fails until you change its ownership. See
[Moving data from the upstream image](#moving-data-from-the-upstream-image-uid-666).

The entrypoint `/bin/keel`, working directory `/`, and port `9300/tcp` match upstream. The runtime variants have no
shell or package manager. Use the `-dev` variant when you need them.

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
