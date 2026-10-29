## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kubernetes-reflector:<tag>`
- Mirrored image: `<your-namespace>/dhi-kubernetes-reflector:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Kubernetes Reflector image

Kubernetes Reflector runs inside a Kubernetes cluster and watches Secrets, ConfigMaps, and namespaces through the
Kubernetes API. Install it with the upstream Helm chart and point the chart's image values at this image.

Create the namespace and a pull secret for `dhi.io`.

```bash
kubectl create namespace reflector

kubectl create secret docker-registry dhi-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<your-docker-username> \
  --docker-password=<your-access-token> \
  --namespace reflector
```

Then install the chart.

```bash
helm repo add emberstack https://emberstack.github.io/helm-charts
helm repo update

helm upgrade --install reflector emberstack/reflector \
  --version <version> \
  --namespace reflector \
  --set image.repository=dhi.io/kubernetes-reflector \
  --set image.tag=<tag> \
  --set "imagePullSecrets[0].name=dhi-pull-secret"

kubectl --namespace reflector rollout status deployment/reflector
```

Replace `<version>` with the chart version you want. Upstream gives each chart release the same number as the
application release, such as `10.0.70`. Short image tags like `10` have no chart release of their own, so use the full
version.

The chart's default security context works with this image as is. It runs the container as UID 1000 with a read-only
root filesystem, and the controller reads its files without writing to the image.

## Common Kubernetes Reflector use cases

### Mirror a Secret into other namespaces

Annotate the source Secret to allow reflection and to create mirrors automatically. This example copies a Secret from
the `source` namespace into `team-a` and `team-b`.

```bash
kubectl create namespace source
kubectl create namespace team-a
kubectl create namespace team-b

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: shared-credentials
  namespace: source
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
    reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "team-a,team-b"
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "team-a,team-b"
stringData:
  password: change-me
EOF
```

The controller creates the mirrors a few seconds later. Check them in both namespaces.

```bash
kubectl get secret shared-credentials --namespace team-a
kubectl get secret shared-credentials --namespace team-b
```

The mirrors follow later changes to the source, and they go away when you delete the source. ConfigMaps take the same
annotations.

### Mirror a ConfigMap on request

A mirror can also pull from a source that allows it. Create the source ConfigMap in `source` and allow `team-a`, then
create a ConfigMap in `team-a` that names the source in a `reflects` annotation.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: shared-settings
  namespace: source
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
    reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "team-a"
data:
  mode: shared
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: shared-settings
  namespace: team-a
  annotations:
    reflector.v1.k8s.emberstack.com/reflects: "source/shared-settings"
EOF
```

A few seconds later the ConfigMap in `team-a` holds the source data.

```bash
kubectl get configmap shared-settings --namespace team-a --output yaml
```

### Other setups

- To mirror certificates that cert-manager issues, see the
  [cert-manager section of the Reflector README](https://github.com/emberstack/kubernetes-reflector#cert-manager-support).
- Logging level, watcher timeout, and excluded namespaces are chart values under `configuration`. See the
  [chart values](https://github.com/emberstack/kubernetes-reflector/blob/main/src/helm/reflector/values.yaml).

## Non-hardened images vs. Docker Hardened Images

The image starts the controller the same way as upstream, with `dotnet ES.Kubernetes.Reflector.dll` from `/app`. The
application lives in `/usr/lib/kubernetes-reflector`, and `/app` is a symlink to it. The working directory matters,
because the controller reads `appsettings.json` from it.

The ASP.NET Core runtime is in `/opt/dotnet` on Debian images and in `/usr/lib/dotnet` on Alpine images. Upstream keeps
it in `/usr/share/dotnet`.

Runtime variants run as the nonroot user with UID 65532 instead of the upstream `app` user with UID 1654.

This image is built for `linux/amd64` and `linux/arm64`. Upstream also publishes `linux/arm/v7`.

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
