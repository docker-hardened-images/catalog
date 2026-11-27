## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The frr-k8s controller turns `FRRConfiguration` resources into FRRouting configuration on each node. It is not a
standalone service. The frr-k8s Helm chart runs it in a DaemonSet next to the FRR, reloader, and metrics containers.
This image supplies the controller, the status cleaner, and the helper binaries that the chart copies into the FRR pod.
Upstream project: https://github.com/metallb/frr-k8s.

### What's included in this metallb-frr-k8s image

This Docker Hardened metallb-frr-k8s image includes:

- `frr-k8s` — Kubernetes controller that reconciles `FRRConfiguration` resources and writes the rendered FRR
  configuration for the node's reloader.
- `statuscleaner` — Validating admission webhook and stale-state cleaner for `FRRConfiguration` resources.
- `frr-metrics` — Prometheus exporter that the chart runs inside the FRR container to serve FRR health and metrics.
- `frr-status` — Exporter that the chart runs inside the FRR container and that produces `BGPSessionState` objects.
- `frr-reloader.sh` — Script that the chart runs inside the FRR container. It applies the rendered configuration and
  records the reload result.

The chart copies `frr-metrics`, `frr-status`, and `frr-reloader.sh` into the FRR pod with init containers. The
controller container runs only `frr-k8s`.

## Start a metallb-frr-k8s image

The controller is deployed by the chart, not run as a single container. The examples below use the standalone `frr-k8s`
chart from `https://metallb.github.io/frr-k8s`.

### Install the chart with a `-compat` tag

The chart's init containers run `/bin/sh -c "cp -f ..."` from the controller image. Runtime tags have no shell, so use a
`-compat` tag. The chart selects the controller image with `frrk8s.image.repository` and `frrk8s.image.tag`:

```bash
helm repo add metallb https://metallb.github.io/frr-k8s
helm repo update
kubectl create namespace frr-k8s-system
helm install frr-k8s metallb/frr-k8s \
  --version 0.0.27 \
  --namespace frr-k8s-system \
  --set frrk8s.image.repository=dhi.io/metallb-frr-k8s \
  --set frrk8s.image.tag=0.0.27-compat
```

The chart's default FRR image is `quay.io/frrouting/frr:10.6.2`. Its reloader runs as root, and the `-compat` controller
also runs as root, so no UID change is needed with that image.

Install one frr-k8s controller per cluster. MetalLB's chart embeds this chart, so do not install both.

### Create an FRRConfiguration

A fresh install renders no BGP router until an `FRRConfiguration` exists. The chart's validating webhook checks every
`FRRConfiguration` and is served by the `frr-k8s-statuscleaner` Deployment, so wait until that Deployment is available.
An `FRRConfiguration` applied earlier fails with `failed calling webhook`.

```bash
kubectl wait --namespace frr-k8s-system --for=condition=Available deployment/frr-k8s-statuscleaner --timeout=300s
```

Then create the `FRRConfiguration` in the chart's namespace. The example below configures a router with ASN 64512 and
one neighbor; replace the neighbor address and ASN with your BGP peer:

```bash
kubectl apply -f - <<'EOF'
apiVersion: frrk8s.metallb.io/v1beta1
kind: FRRConfiguration
metadata:
  name: base
  namespace: frr-k8s-system
spec:
  bgp:
    routers:
      - asn: 64512
        neighbors:
          - address: 192.0.2.1
            asn: 64513
EOF
```

### Check the rendered configuration

Each node has one `FRRNodeState`, named after the node. Check its last conversion and reload results:

```bash
kubectl get frrnodestate <node-name> -o jsonpath='{.status.lastConversionResult}{"\n"}{.status.lastReloadResult}{"\n"}'
kubectl get bgpsessionstates.frrk8s.metallb.io -A
```

Both results should read `success`. `status.runningConfig` on the same object holds the configuration FRR is running and
includes `router bgp 64512`. `frr-status` polls FRR every two minutes, so the `BGPSessionState` for the neighbor can
take that long to appear.

### Align the controller user with the FRR reloader

The controller signals the reloader process through the shared process namespace. The chart drops all capabilities from
the controller except `NET_RAW`, so the kernel allows that signal only when both processes run as the same user ID. The
controller writes the rendered `frr.conf` to `/etc/frr_reloader/frr.conf` and reads the reloader's PID from
`/etc/frr_reloader/reloader.pid`. The chart sets both paths.

The only pairing this image supports is the one in the install section that uses a `-compat` tag:

| FRR image                                      | Reloader user | Controller image                       | Controller user |
| ---------------------------------------------- | ------------- | -------------------------------------- | --------------- |
| `quay.io/frrouting/frr:10.6.2` (chart default) | root (0)      | `dhi.io/metallb-frr-k8s:0.0.27-compat` | root (0)        |

The chart has no value for the controller's `runAsUser`, so no other pairing can be set through the chart. Other FRR
images, including `dhi.io/frr`, have not been tested with this image and are not supported.

### Runtime tag

The runtime tag (`dhi.io/metallb-frr-k8s:0.0.27`) runs as UID 65532 and has no shell. The chart's init containers cannot
run with it, and a controller running as UID 65532 cannot signal the root reloader of the stock FRR image. The runtime
tag is not supported as the controller image for the chart. Use the `-compat` tag.

### Limits

- The checks above confirm that the rendered configuration reaches FRR (`runningConfig`), that the last reload succeeded
  (`lastReloadResult`), and that `BGPSessionState` objects exist. They do not confirm that a BGP peer session is
  established.
- Only the stock FRR image with the `-compat` controller tag has been tested with the chart. No other FRR image has been
  tested for reloads.

### Ports and health checks

The ports below come from the chart's defaults and are not declared by this image.

- Controller: HTTPS metrics on port `9140` on all interfaces. Health and readiness probes on `127.0.0.1:7572`.
- Status cleaner: validating webhook on port `19443`.
- `frr-metrics` in the FRR container: HTTPS metrics on port `9141`.

## Non-hardened images vs. Docker Hardened Images

The upstream image `quay.io/metallb/frr-k8s:v0.0.27` has no entrypoint, runs `/bin/sh` by default, and runs as root.
This image differs in these ways:

- **Command.** The image has no entrypoint, as upstream. The default command is the controller `/usr/bin/frr-k8s` on the
  runtime and FIPS tags, because they have no shell, and `/bin/sh` on the `-compat` and `-dev` tags, as upstream.
  Arguments run the named binary directly, so `docker run <image> /statuscleaner --help` works as it does upstream.
  Running the runtime tag with no arguments starts the controller; to start it with arguments, pass the path, for
  example `docker run <image> /usr/bin/frr-k8s --help`.
- **User.** The runtime and FIPS runtime tags run as `nonroot` (UID 65532). The `-compat` and `-dev` tags run as root.
  The chart has no `runAsUser` setting, so use the `-compat` tag with the stock FRR image, as described above.
- **Shell and tools.** Runtime tags have no shell and no package manager. `-compat` tags add `/bin/sh` and `cp` from
  BusyBox (`busybox-static` on Debian, `busybox` on Alpine). `-dev` tags add a shell, a package manager, and development
  tools. If you need a shell, use a `-compat` or `-dev` tag.
- **Platforms.** This image ships `linux/amd64` and `linux/arm64` only. Upstream also publishes `linux/s390x`,
  `linux/ppc64le`, `linux/arm/v7` and `linux/riscv64`.

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
