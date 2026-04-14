## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/istio-pilot:<tag>`
- Mirrored image: `<your-namespace>/dhi-istio-pilot:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Istio Pilot image

This Docker Hardened Image includes:

- `pilot-discovery` binary — the Istio control plane (Istiod) for service discovery and configuration distribution
- mTLS certificate issuance and rotation via built-in CA
- Configuration validation webhook support
- TLS certificates (`SSL_CERT_FILE` pre-configured)
- CIS benchmark compliance (runtime), FIPS 140 + STIG + CIS compliance (FIPS variant)

## Start an Istio Pilot instance

The Istio Pilot image (also known as Istiod) is the control plane component that manages service discovery,
configuration distribution, and certificate management for the Istio service mesh. It is designed to run as a Deployment
in Kubernetes and requires a Kubernetes environment to function fully.

Run the following command and replace `<tag>` with the image variant you want to run (for example, `1.28-debian13`):

```console
$ docker run --rm dhi.io/istio-pilot:<tag> version
```

To check the short version:

```console
$ docker run --rm dhi.io/istio-pilot:<tag> version --short
```

To view all available discovery flags:

```console
$ docker run --rm dhi.io/istio-pilot:<tag> discovery --help
```

## Common Istio Pilot use cases

### Start the proxy discovery service

Istiod provides xDS-based service discovery, configuration distribution, and proxy management for all Envoy sidecars in
the mesh. In a Kubernetes deployment, it listens on the following ports:

- `:15010` — gRPC (plaintext)
- `:15012` — gRPC (TLS)
- `:15017` — HTTPS (injection and validation webhooks)
- `:15014` — HTTP (self-monitoring and metrics)
- `:9876` — ControlZ introspection

```console
$ docker run --rm dhi.io/istio-pilot:<tag> discovery --help
```

### Query Pilot metrics and debug endpoints

Use the `request` subcommand to make HTTP requests to Pilot's internal metrics and debug endpoint while Istiod is
running in Kubernetes:

```console
$ docker run --rm dhi.io/istio-pilot:<tag> request --help
```

### Check Istio Pilot version

Verify the version of the Istio Pilot image:

```console
$ docker run --rm dhi.io/istio-pilot:<tag> version
```

For a concise single-line output:

```console
$ docker run --rm dhi.io/istio-pilot:<tag> version --short
```

### Deploy Istio Pilot in Kubernetes

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

**Step 1: Create the namespace**

```console
$ kubectl create namespace istio-system
```

**Step 2: Create the image pull secret**

```console
$ kubectl create secret docker-registry dhi-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<your-docker-username> \
  --docker-password=<your-docker-token> \
  -n istio-system
```

**Step 3: Create the ServiceAccount**

```console
$ kubectl create serviceaccount istiod -n istio-system
```

**Step 4: Create the ClusterRole and bindings**

Istiod requires cluster-wide permissions to manage service discovery, webhooks, and leader election:

```console
$ kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: istiod-clusterrole
rules:
- apiGroups: [""]
  resources: ["namespaces", "configmaps", "endpoints", "pods", "services", "secrets", "nodes", "serviceaccounts"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "ingressclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["validatingwebhookconfigurations", "mutatingwebhookconfigurations"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["discovery.k8s.io"]
  resources: ["endpointslices"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF
```

```console
$ kubectl create clusterrolebinding istiod-clusterrolebinding \
  --clusterrole=istiod-clusterrole \
  --serviceaccount=istio-system:istiod
```

**Step 5: Create the deployment YAML**

Save the following as `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: istiod
  template:
    metadata:
      labels:
        app: istiod
    spec:
      serviceAccountName: istiod
      imagePullSecrets:
      - name: dhi-pull-secret
      containers:
      - name: discovery
        image: dhi.io/istio-pilot:<tag>
        command: ["pilot-discovery", "discovery"]
        ports:
        - containerPort: 15010
        - containerPort: 15012
        - containerPort: 15014
        - containerPort: 15017
        securityContext:
          runAsUser: 1337
```

> **Note:** This configuration uses `runAsUser: 1337` which matches the user set in the DHI image. The Istio project
> uses UID `1337` by convention for the `istio-proxy` user.

> **Note:** The `command: ["pilot-discovery", "discovery"]` is required. Without it, the container prints help text and
> exits immediately.

**Step 6: Apply and verify**

```console
$ kubectl apply -f deployment.yaml
$ kubectl get pods -n istio-system
```

**Step 7: Confirm Istiod is running**

```console
$ kubectl logs -n istio-system -l app=istiod --tail=20
```

A healthy Istiod will show output similar to:

```
info    leader election lock obtained: istio-leader
info    Starting ingress status writer
info    leader election lock obtained: istio-gateway-deployment-default
info    ads     XDS: Pushing Services:2 ConnectedEndpoints:0 Version:...
```

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature             | DOI (`istio/pilot`)                      | DHI (`dhi.io/istio-pilot`)           |
| ------------------- | ---------------------------------------- | ------------------------------------ |
| User                | `1337:1337`                              | `1337`                               |
| Shell               | sh (present)                             | none                                 |
| Package manager     | apt-get (present)                        | none                                 |
| Entrypoint          | `["/usr/local/bin/pilot-discovery"]`     | `["/usr/local/bin/pilot-discovery"]` |
| Uncompressed size   | 375MB                                    | 225MB (runtime), 351MB (dev)         |
| Zero CVE commitment | No                                       | Yes                                  |
| FIPS variant        | No                                       | Yes (FIPS + STIG + CIS)              |
| Base OS             | Ubuntu 24.04 LTS                         | Docker Hardened Images (Debian 13)   |
| Compliance labels   | None                                     | CIS (runtime), FIPS+STIG+CIS (fips)  |
| ENV                 | `PATH`, `DEBIAN_FRONTEND=noninteractive` | `PATH`, `SSL_CERT_FILE`              |
| Architectures       | amd64, arm64                             | amd64, arm64                         |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

**Runtime variants** are intended for production use. They run as user `1337`, contain no shell and no package manager,
and are CIS benchmark compliant.

**Dev variants** are intended for build and development use. They run as `root`, include `bash` and `apt-get`, and are
useful for multi-stage builds or debugging workflows.

**FIPS variants** are intended for environments requiring FIPS 140, STIG, and CIS compliance. They run as user `1337`
with no shell or package manager.

> **Note:** FIPS variants require a Docker Hardened Images subscription. Start a free 30-day trial at
> [https://dhi.io](https://dhi.io).

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                                                    |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

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

## Troubleshoot migration

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
