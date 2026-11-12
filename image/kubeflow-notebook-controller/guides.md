## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kubeflow-notebook-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-kubeflow-notebook-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Kubeflow Notebook Controller image

The controller runs as a controller-manager. The entrypoint is `/manager`, the image has no default command, and the
working directory is `/`. The controller needs a Kubernetes cluster with the `Notebook` CRD and RBAC rules before it can
reconcile anything, so the local check below prints the available flags with `--help`:

```bash
docker run --rm dhi.io/kubeflow-notebook-controller:<tag> --help
```

Replace `<tag>` with a published tag, such as `1.11.1-debian13` or `1.11.1-alpine3.24`.

### Run in Kubernetes

The following overlay uses the upstream `config/default` kustomization at the `v1.11.1` tag. It installs the
`notebooks.kubeflow.org` CRD, the RBAC rules for StatefulSets, Services, and Notebooks, and the controller Deployment in
the `notebook-controller-system` namespace. The overlay replaces the upstream controller image with this image, and runs
the controller as uid and gid 65532, the image's numeric user and group:

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - github.com/kubeflow/notebooks/components/notebook-controller/config/default?ref=v1.11.1
images:
  - name: ghcr.io/kubeflow/notebooks/notebook-controller
    newName: dhi.io/kubeflow-notebook-controller
    newTag: 1.11.1-debian13
configMapGenerator:
  - name: config
    behavior: merge
    literals:
      - USE_ISTIO=false
patches:
  - target:
      kind: Deployment
      name: notebook-controller-deployment
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/securityContext/runAsUser
        value: 65532
      - op: add
        path: /spec/template/spec/containers/0/securityContext/runAsGroup
        value: 65532
```

Apply it with:

```bash
kubectl apply -k .
```

Your cluster must be able to pull from `dhi.io`, for example through an image pull secret.

The upstream Deployment sets `runAsUser: 1000` and no group. This image runs as uid and gid 65532, so the overlay sets
both to 65532 and keeps the upstream `runAsNonRoot: true`. For build steps and the full deployment flow, see the
[upstream component README](https://github.com/kubeflow/notebooks/tree/v1.11.1/components/notebook-controller).

The upstream `config/default` sets `USE_ISTIO=true`, so the controller reconciles Istio `VirtualService` objects. The
`configMapGenerator` in the overlay sets `USE_ISTIO=false`, so this example starts on a cluster without Istio. On a
cluster that runs Istio, set it to `true`. [Turn on culling and set Istio](#turn-on-culling-and-set-istio) shows the
same setting alongside culling.

## Common use cases

### Run with leader election

Leader election ensures that only one controller manager is active at a time. Enable it if you run more than one
replica. Add these entries to the `patches` list of the overlay from the previous section:

```yaml
- target:
    kind: Deployment
    name: notebook-controller-deployment
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/args
      value: ["--enable-leader-election"]
- target:
    kind: Role
    name: notebook-controller-leader-election-role
  patch: |-
    - op: add
      path: /rules/-
      value:
        apiGroups:
          - coordination.k8s.io
        resources:
          - leases
        verbs:
          - get
          - create
          - update
```

The upstream leader-election Role grants permissions on ConfigMaps and Events only. The controller takes its
leader-election lock on a Lease as well, so the second entry grants the Lease permissions. Without it, the manager
repeatedly fails Lease `get` and `create` with `forbidden`, never becomes leader, and does not reconcile Notebooks.

### Turn on culling and set Istio

The upstream manifests read their runtime settings from a ConfigMap named `config`. The upstream defaults are in
[`params.env`](https://raw.githubusercontent.com/kubeflow/notebooks/v1.11.1/components/notebook-controller/config/manager/params.env):
`USE_ISTIO=true`, `ENABLE_CULLING=false`, `CULL_IDLE_TIME=1440`, and `IDLENESS_CHECK_PERIOD=1`. This overlay turns on
culling and sets Istio usage explicitly. Set `USE_ISTIO` to match whether your cluster runs Istio. Replace the
`configMapGenerator` from the first example with this one, so the `config` ConfigMap has a single entry:

```yaml
configMapGenerator:
  - name: config
    behavior: merge
    literals:
      - ENABLE_CULLING=true
      - USE_ISTIO=false
```

## Non-hardened images vs. Docker Hardened Images

- **Ports.** The image declares `8080/tcp` (metrics) and `8081/tcp` (health probes). The upstream image does not declare
  them, but the controller listens on both by default (`--metrics-addr=:8080` and `--probe-addr=:8081`).
- **Entrypoint path.** The controller binary is at `/usr/bin/manager`, and `/manager` is a symlink to it. The entrypoint
  path matches the upstream image, so manifests that run `/manager` keep working.
- **User.** The runtime image runs as `nonroot` (uid and gid 65532), the same user as the upstream image. The upstream
  Deployment manifest sets uid 1000 instead. The Kubernetes example in [Run in Kubernetes](#run-in-kubernetes) sets uid
  and gid 65532 to match the image.
- **Shell and package manager.** Runtime images include neither. The `dev` variants run as root and include a shell and
  a package manager.

## FIPS variants

The `-fips` and `-fips-dev` tags, such as `1.11.1-debian13-fips` and `1.11.1-alpine3.24-fips`, are FIPS builds. They use
the Go FIPS 140-3 module and an OpenSSL FIPS provider on the operating system. The image metadata declares
`fips-compliant: true` and `stig-certified: true`. Use these tags when your environment requires FIPS-compliant builds.

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
