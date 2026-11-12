## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/rancher-webhook:<tag>`
- Mirrored image: `<your-namespace>/dhi-rancher-webhook:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Rancher Webhook image

Rancher Webhook needs a Kubernetes cluster. It connects through the pod's service account (or `KUBECONFIG`), creates its
serving certificate in the `cattle-system` namespace, and registers its hooks in the `rancher.cattle.io`
ValidatingWebhookConfiguration and MutatingWebhookConfiguration. Rancher installs it in every cluster it runs or
manages, using the `rancher-webhook` Helm chart at the version each Rancher release pins.

Use the tag line for your Rancher version: `0.11` for Rancher 2.15, `0.10` for 2.14, `0.9` for 2.13 and `0.8` for 2.12.
The Debian-based tags also come in the upstream form, for example `v0.11.4`. The newest Rancher patch of each minor pins
the newest webhook patch. With an older Rancher patch, the hardened image is newer than the one Rancher pins.

### Environment variables

The chart sets these variables from its values.

| Variable      | Description                                                                                                     | Default | Required |
| ------------- | --------------------------------------------------------------------------------------------------------------- | ------- | -------- |
| `CATTLE_PORT` | HTTPS port the webhook listens on. Set through the chart value `port`.                                          | `9443`  | No       |
| `ENABLE_MCM`  | `false` turns off the validators and mutators that need a Rancher management server. Set through `mcm.enabled`. | `true`  | No       |

## Common Rancher Webhook use cases

The FIPS tags come only with a DHI Select or DHI Enterprise subscription, from a mirrored repository. For them, use
`<your-namespace>/dhi-rancher-webhook` instead of `dhi.io/rancher-webhook` in both setups below, and `docker.io` as the
pull secret's server.

### Point Rancher at the hardened image

Rancher passes the Rancher chart's `webhook` value to the webhook chart it installs, as Helm values. Set the image
there, with a pull secret for `dhi.io`. Replace:

- `<version>` with a hardened release of your Rancher's line, for example `0.11.4` (`0.11.4-fips` for FIPS).
- `<rancher-repo>` with the Helm repository you installed Rancher from.
- `<rancher-version>` with the Rancher version you run, so the upgrade changes only the webhook values.

```bash
$ kubectl -n cattle-system create secret docker-registry dhi-pull \
  --docker-server=dhi.io --docker-username=<username> --docker-password=<access-token>
$ cat > webhook-values.yaml <<'EOF'
webhook: |
  image:
    repository: dhi.io/rancher-webhook
    tag: <version>
  global:
    cattle:
      imagePullSecrets:
        - dhi-pull
EOF
$ helm upgrade rancher <rancher-repo>/rancher --namespace cattle-system --version <rancher-version> \
  --reuse-values -f webhook-values.yaml
```

Check that Rancher reinstalled the webhook with the hardened image:

```bash
$ kubectl -n cattle-system rollout status deployment rancher-webhook
$ kubectl -n cattle-system get deployment rancher-webhook \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

This changes the webhook only on the cluster Rancher runs on. Copy the image into a private registry instead, as in the
next section:

- For the clusters Rancher manages, which get their webhook settings separately.
- On Rancher 2.12, 2.13 and 2.14, whose webhook charts have no `global.cattle.imagePullSecrets` value.
- When Rancher uses a system default registry, which the chart puts in front of `dhi.io/rancher-webhook`.

### Run the webhook from a private registry

With a system default registry or a cluster private registry set, Rancher installs the webhook from
`<registry>/rancher/rancher-webhook:v<version>`, where `v<version>` is the tag the Rancher release pins. Copy the
hardened image of the same line to that path and tag before Rancher installs or upgrades the webhook. Rancher then pulls
it with no other change.

Find the tag in the image list of the Rancher release you install or upgrade to. Replace `<rancher-version>` with that
release, for example `2.15.3`:

```bash
$ curl -fsSL https://github.com/rancher/rancher/releases/download/v<rancher-version>/rancher-images.txt \
  | grep rancher/rancher-webhook
rancher/rancher-webhook:v0.11.4
```

Copy the newest hardened image of that line into your registry, with every platform. Replace `<version>` with the
version from the list, without the `v`, and `<line>` with its first two numbers, for example `0.11` for `0.11.4`
(`0.11-fips` for FIPS):

```bash
$ docker buildx imagetools create \
  --tag <registry>/rancher/rancher-webhook:v<version> \
  dhi.io/rancher-webhook:<line>
```

The chart pulls with `imagePullPolicy: IfNotPresent`, so a node that already holds the upstream image under that tag
keeps running it.

For the resources each validator and mutator checks, see the upstream
[docs.md](https://github.com/rancher/webhook/blob/main/docs.md).

## Non-hardened images vs. Docker Hardened Images

- Entrypoint: the upstream image sets no entrypoint and runs `CMD ["webhook"]`. The hardened image runs the same binary,
  `/usr/bin/webhook`, as its entrypoint and sets no command. The chart sets neither `command` nor `args`, so both start
  the same binary.
- User: the upstream image runs as the user `webhook` (uid 1000). Runtime variants of the hardened image run as the user
  `webhook` with uid 65532.
- Shell: the upstream image ships `bash` and coreutils. Runtime variants of the hardened image ship no shell; the `dev`
  variants do.
- TLS: upstream enables two ChaCha20-Poly1305 cipher suites for TLS 1.2 connections. The FIPS variants refuse them and
  negotiate only FIPS-approved suites.
- Tags: the Debian-based tags include the upstream tag form, such as `v0.11.4`, `v0.11.4-dev` and `v0.11.4-fips`. The
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
