## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/datadog-operator:<tag>`
- Mirrored image: `<your-namespace>/dhi-datadog-operator:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Datadog Operator image

This Docker Hardened Datadog Operator image contains the binaries needed to run the Datadog Operator in a Kubernetes
cluster. The operator manages the full lifecycle of Datadog Agent deployments through the `DatadogAgent` custom resource
(v2alpha1). Features enabled by default include the Cluster Agent, Admission Controller, Kubernetes Event Collection,
Kubernetes State Core Check, and Orchestrator Explorer.

The image ships three binaries:

- `manager` — the main operator process; serves Prometheus metrics on port 8080 and the health probe on port 8081.
- `helpers` — utility commands used by the operator.
- `yaml-mapper` — converts YAML resources as part of operator migrations.

### Run the Datadog Operator container

The Datadog Operator is designed to run inside a Kubernetes cluster. Standalone `docker run` is useful only to confirm
the binary version or inspect flags. The operator exits immediately without valid in-cluster credentials.

To print version information:

```bash
docker run --rm dhi.io/datadog-operator:<tag> --version
```

To print available flags:

```bash
docker run --rm dhi.io/datadog-operator:<tag> --help
```

### Deploy with Helm (recommended)

The recommended way to deploy the Datadog Operator is through the official Helm chart. To use the Docker Hardened image,
override the image repository and tag in your Helm values.

1. Add the Datadog Helm repository:

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update
```

2. Install the operator with the Docker Hardened image:

```bash
helm install datadog-operator datadog/datadog-operator \
  --set image.repository=dhi.io/datadog-operator \
  --set image.tag=<tag>
```

3. Verify the operator pod is running:

```bash
kubectl get pods -l app.kubernetes.io/name=datadog-operator
```

For the full list of Helm values, see the
[Datadog Operator Helm chart documentation](https://github.com/DataDog/helm-charts/tree/main/charts/datadog-operator).

### Deploy with Kubernetes manifests

If you manage your own operator manifests, update the `image` field in the operator `Deployment` to reference the Docker
Hardened image:

```yaml
containers:
  - name: manager
    image: dhi.io/datadog-operator:<tag>
```

After updating the manifest, apply it with:

```bash
kubectl apply -f datadog-operator.yaml
```

### Configure the Datadog Agent

Once the operator is running, create a `DatadogAgent` custom resource to deploy Datadog Agents on your nodes. Agent
configuration is standard upstream Datadog behavior and is unchanged by this hardened image — see the
[DatadogAgent v2alpha1 configuration docs](https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md)
for the full spec and examples.

### Health and metrics endpoints

When the operator is running in-cluster, the following endpoints are available on the operator pod:

| Endpoint   | Port | Description                             |
| ---------- | ---- | --------------------------------------- |
| `/metrics` | 8080 | Prometheus metrics endpoint             |
| `/healthz` | 8081 | Liveness probe endpoint (returns `ok`)  |
| `/readyz`  | 8081 | Readiness probe endpoint (returns `ok`) |

Both ports use unprivileged values (above 1024) and are compatible with the DHI nonroot runtime.

### Secret backend command

Upstream ships a `/readsecret.sh` wrapper that simply calls `helpers read-secret`. The hardened runtime has no shell to
execute that script, so it is not included; the `helpers` binary itself is. If you configured
`secretBackend.command: /readsecret.sh`, point it at the binary instead:

```yaml
spec:
  global:
    secretBackend:
      command: /helpers
      args: "read-secret"
```

Alternatively, use one of the operator's native `secretBackend` types.

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
