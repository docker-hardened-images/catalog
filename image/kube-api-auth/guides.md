## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kube-api-auth:<tag>`
- Mirrored image: `<your-namespace>/dhi-kube-api-auth:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a kube-api-auth image

kube-api-auth needs a Kubernetes cluster that holds Rancher's `ClusterAuthToken` and `ClusterUserAttribute` resources.
Rancher deploys it as the `kube-api-auth` DaemonSet in the `cattle-system` namespace of every downstream cluster with
the authorized cluster endpoint enabled. The DaemonSet runs on the control plane nodes with host networking, so the
kube-apiserver reaches the webhook on `127.0.0.1:6440`.

Use the tag line for your Rancher version: `0.15` for Rancher 2.15, and `0.13` for Rancher 2.13 and 2.14. The
Debian-based tags also come in the upstream form, for example `v0.15.4`.

### Flags

kube-api-auth takes its settings as flags. The image runs `kube-api-auth serve` by default. A command you pass replaces
it, so start it with `kube-api-auth`, end the flags with `serve`, and put `--listen` after it. For example:
`kube-api-auth --debug --namespace cattle-system serve --listen 127.0.0.1:6440`.

| Flag             | Description                                                                                                                              | Default          |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| `--kubeconfig`   | Path to a kubeconfig for the cluster. The `KUBECONFIG` environment variable sets it too. Without either, the in-cluster service account. | in-cluster       |
| `--namespace`    | Namespace of the `ClusterAuthToken` and `ClusterUserAttribute` resources and the token hash Secrets.                                     | `cattle-system`  |
| `--debug`        | Turns on debug logging.                                                                                                                  | off              |
| `serve --listen` | Host and port the webhook listens on.                                                                                                    | `127.0.0.1:6440` |

## Common kube-api-auth use cases

The FIPS tags come only with a DHI Select or DHI Enterprise subscription, from a mirrored repository.

### Run kube-api-auth from a private registry

With a system default registry or a cluster private registry set, Rancher deploys kube-api-auth from
`<registry>/rancher/kube-api-auth:v<version>`, where `v<version>` is the tag the Rancher release pins. Copy the hardened
image of the same line to that path and tag. Rancher then deploys it with no other change.

Find the tag your Rancher release pins in the default of its `auth-image` setting. Run this against the cluster Rancher
runs on:

```bash
$ kubectl get settings.management.cattle.io auth-image -o jsonpath='{.default}'
rancher/kube-api-auth:v0.15.4
```

Copy the newest hardened image of that line into your registry, with every platform. Replace `<version>` with the
version in that tag, without the `v`, and `<line>` with its first two numbers, for example `0.15` for `0.15.4`:

```bash
$ docker buildx imagetools create \
  --tag <registry>/rancher/kube-api-auth:v<version> \
  dhi.io/kube-api-auth:<line>
```

For FIPS, copy from your mirrored repository instead, for example `<your-namespace>/dhi-kube-api-auth:0.15-fips`.

The DaemonSet pulls with `imagePullPolicy: IfNotPresent`, so a node that already holds the upstream image under that tag
keeps running it.

### Point Rancher at the hardened image

Without a private registry, set Rancher's `auth-image` setting to a copy of the hardened image that your nodes can pull.
Rancher redeploys the DaemonSet on every downstream cluster that uses the authorized cluster endpoint. Run this against
the cluster Rancher runs on, replacing `<image>` with the copy, for example `registry.example.com/kube-api-auth:0.15`:

```bash
$ kubectl patch settings.management.cattle.io auth-image --type merge -p '{"value":"<image>"}'
```

Check the image the DaemonSet runs on a downstream cluster:

```bash
$ kubectl -n cattle-system rollout status daemonset kube-api-auth
$ kubectl -n cattle-system get daemonset kube-api-auth \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Non-hardened images vs. Docker Hardened Images

- User: the upstream image runs as the user `kubeapiauth` (uid 1000). Runtime variants of the hardened image run as the
  user `kubeapiauth` with uid 65532. kube-api-auth writes no files, and Rancher's DaemonSet sets no `runAsUser`.
- TLS: the FIPS variants connect to the Kubernetes API only over FIPS-approved TLS versions and cipher suites.
- Tags: the Debian-based tags include the upstream tag form, such as `v0.15.4`, `v0.15.4-dev` and `v0.15.4-fips`. The
  Alpine-based tags do not.

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
