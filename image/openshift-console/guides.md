## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/openshift-console:4.22`
- Mirrored image: `<your-namespace>/dhi-openshift-console:4.22`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This Docker Hardened image packages the console used by Red Hat® OpenShift® and OKD: its Go backend, `bridge`, together
with the compiled React/TypeScript frontend. `bridge` is a reverse proxy and API gateway that serves the frontend's
static assets and proxies authenticated requests to the Kubernetes API server, OAuth, and in-cluster services such as
Alertmanager, Thanos, Prometheus, and GitOps.

### Start an OpenShift Console instance

The console requires cluster-specific configuration for normal use. This local smoke test starts the server with
authentication disabled and a deliberately unreachable API endpoint, which is enough to verify the health endpoint and
static UI without granting access to a real cluster:

```bash
$ docker run -d --name openshift-console -p 127.0.0.1:9000:9000 \
    dhi.io/openshift-console:4.22 \
    /usr/local/bin/openshift-console \
    --public-dir=/opt/bridge/static \
    --listen=http://0.0.0.0:9000 \
    --k8s-mode=off-cluster \
    --k8s-mode-off-cluster-endpoint=https://127.0.0.1:6443 \
    --user-auth=disabled \
    --k8s-auth-bearer-token=local-smoke-test
$ curl --fail http://127.0.0.1:9000/health
$ docker rm --force openshift-console
```

This smoke test binds only to loopback. The page loads, but cluster-backed API calls fail because the example endpoint
does not exist. For a functional console, use one of the cluster-connected configurations below. To inspect every
supported flag, run `docker run --rm dhi.io/openshift-console:4.22 /usr/local/bin/openshift-console --help`.

## Common openshift-console use cases

### Run in-cluster with a Kubernetes Deployment

This is how the console actually runs in production: as a Pod, reading the Pod's automatically-mounted service account
token and CA certificate to reach the API server.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: console
  namespace: openshift-console
spec:
  replicas: 2
  selector:
    matchLabels:
      app: console
  template:
    metadata:
      labels:
        app: console
    spec:
      serviceAccountName: console
      containers:
        - name: console
          image: dhi.io/openshift-console:4.22
          # The image ships no entrypoint (the binary is its CMD), so name the
          # binary in command: and pass flags as args:.
          command:
            - /usr/local/bin/openshift-console
          args:
            - --public-dir=/opt/bridge/static
            - --listen=https://0.0.0.0:8443
            - --base-address=https://console.apps.example.com
            - --user-auth=openshift
            - --user-auth-oidc-client-id=console
            - --user-auth-oidc-client-secret-file=/var/run/secrets/console-auth/client-secret
            - --tls-cert-file=/var/run/secrets/console-tls/tls.crt
            - --tls-key-file=/var/run/secrets/console-tls/tls.key
          ports:
            - name: https
              containerPort: 8443
          volumeMounts:
            - name: console-auth
              mountPath: /var/run/secrets/console-auth
              readOnly: true
            - name: console-tls
              mountPath: /var/run/secrets/console-tls
              readOnly: true
          readinessProbe:
            httpGet:
              path: /health
              port: https
              scheme: HTTPS
          livenessProbe:
            httpGet:
              path: /health
              port: https
              scheme: HTTPS
      volumes:
        - name: console-auth
          secret:
            secretName: console-oauth-client
        - name: console-tls
          secret:
            secretName: console-tls
```

`--k8s-mode` defaults to `in-cluster`, so no flag is needed for it. Kubernetes automatically mounts the `console`
service account's token and CA certificate at `/var/run/secrets/kubernetes.io/serviceaccount/`, which is what `bridge`
reads to authenticate to the API server. `/health` is an unauthenticated liveness/readiness endpoint served by `bridge`
itself.

This Deployment assumes that the namespace already contains:

- A `console-tls` TLS Secret valid for `console.apps.example.com`.
- A `console-oauth-client` Secret whose `client-secret` key matches an OpenShift `OAuthClient` named `console`, with
  `https://console.apps.example.com/auth/callback` registered as a redirect URI.
- A `console` ServiceAccount with the RBAC permissions required by the console.

The OpenShift console-operator normally creates and rotates these resources, adds the cluster service CA, configures
monitoring and plugin endpoints, and exposes the Deployment through a Service and Route. Use the manifest above only
when you intentionally manage those dependencies yourself.

For the full set of flags and how the operator wires them together, see the
[console-operator](https://github.com/openshift/console-operator) repository and the
[OpenShift web console documentation](https://docs.openshift.com/container-platform/latest/web_console/web-console-overview.html).

### Run off-cluster for local development

To point the console at an existing cluster from outside it, for example on a developer workstation, use
`--k8s-mode=off-cluster` with a bearer token instead of the in-cluster service account:

```bash
$ docker run --rm -p 127.0.0.1:9000:9000 \
    -e BRIDGE_K8S_MODE=off-cluster \
    -e BRIDGE_K8S_MODE_OFF_CLUSTER_ENDPOINT="$(oc whoami --show-server)" \
    -e BRIDGE_K8S_MODE_OFF_CLUSTER_SKIP_VERIFY_TLS=true \
    -e BRIDGE_USER_AUTH=disabled \
    -e BRIDGE_K8S_AUTH_BEARER_TOKEN="$(oc whoami --show-token)" \
    dhi.io/openshift-console:4.22
```

Every `bridge` flag can also be set as a `BRIDGE_<FLAG_NAME>` environment variable, which is how this example passes
them. `BRIDGE_USER_AUTH=disabled` skips the OAuth login flow entirely and serves the console using the bearer token's
own permissions, so bind it to `127.0.0.1` only — this mode has no login page and anyone who can reach the port has full
access as that user. `BRIDGE_K8S_MODE_OFF_CLUSTER_SKIP_VERIFY_TLS` is for development against clusters with self-signed
certificates and should not be used in production.

For the complete off-cluster flag set, including wiring up Alertmanager, Thanos, and GitOps endpoints, see upstream's
[`examples/run-bridge.sh`](https://github.com/openshift/console/blob/main/examples/run-bridge.sh) and the
[Frontend Development](https://github.com/openshift/console/blob/main/README.md#frontend-development) and
[Backend](https://github.com/openshift/console/blob/main/README.md#backend) sections of the upstream README.

## Non-hardened images vs. Docker Hardened Images

This image's default command runs `/usr/local/bin/openshift-console`, a symlink to `/opt/bridge/bin/bridge` — the
upstream binary path remains resolvable, so scripts or health checks that exec `/opt/bridge/bin/bridge` directly keep
working. Like upstream, the image sets no entrypoint, so an override that appends flags must name the binary. Runtime
variants of this image run as the nonroot user, whereas the upstream image runs as the fixed non-root UID 1001
(`USER 1001` in its Dockerfile).

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
