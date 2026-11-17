## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/telepresence:<tag>`
- Mirrored image: `<your-namespace>/dhi-telepresence:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Telepresence connects a developer workstation to a remote Kubernetes cluster. This image is the Telepresence client
image. The `telepresence connect --docker` command on your host starts it as the daemon container. The same image also
runs the `telepresence` CLI, for example to install the cluster-side traffic manager. The image is the hardened stand-in
for `ghcr.io/telepresenceio/telepresence`. Full documentation is at https://telepresence.io/docs.

This image does not contain the cluster-side traffic manager or traffic agent. Those run from the separate image
`ghcr.io/telepresenceio/tel2`, which `telepresence helm install` deploys into your cluster.

The entrypoint is `telepresence` and there is no default command. If you pass no arguments, the container prints the CLI
help. The image runs as the root user. See
[Non-hardened images vs. Docker Hardened Images](#non-hardened-images-vs-docker-hardened-images) for the reason.

## Start a telepresence image

### Check the version

```bash
docker run --rm dhi.io/telepresence:<tag> version
```

The container prints the client version. The root daemon and the user daemon show `not running` because no daemon runs
in this container.

### Use the image as the daemon container for `telepresence connect --docker`

Install the Telepresence CLI on your host, as described in the
[upstream install guide](https://telepresence.io/docs/install/client). Then set the client image in the Telepresence
configuration file on your host. The file is `$XDG_CONFIG_HOME/telepresence/config.yml` (or
`$HOME/.config/telepresence/config.yml`) on Linux, and `$HOME/Library/Application Support/telepresence/config.yml` on
macOS. The key is `images.clientImage`:

```yaml
images:
  clientImage: dhi.io/telepresence:<tag>
```

Use a tag that matches the version of your host CLI. The default image of the upstream CLI uses the CLI version as its
tag. To see your CLI version, run `telepresence version`. You can also set the image with the environment variable
`TELEPRESENCE_CLIENT_IMAGE` instead of the file.

Then connect with the `--docker` flag:

```bash
telepresence connect --docker
```

The CLI pulls the image, starts it as a container, and connects it to your cluster. Check the result with
`telepresence status`. Commands such as `telepresence curl` then use the network of this container. The FIPS variants,
for example `dhi.io/telepresence:<tag>-fips`, work the same way. Run `telepresence quit` to stop the daemon container.

The CLI also installs the Docker network plugin `ghcr.io/telepresenceio/teleroute` on your host, with all permissions,
when the plugin is not installed. The plugin is not part of this image. To install it from a mirror, set
`docker.teleroute` in the same configuration file. Set the `tag`, because the CLI cannot list the tags of a mirror:

```yaml
docker:
  teleroute:
    registry: <your-registry>
    namespace: <your-namespace>
    repository: teleroute
    tag: "<tag>"
```

If you mount remote volumes, the CLI installs a second plugin, `telemount`. The `docker.telemount` setting redirects it
in the same way.

The CLI starts the container with `--cap-add NET_ADMIN`, `--device /dev/net/tun:/dev/net/tun`, `--pid host`, the
environment variables `TELEPRESENCE_UID` and `TELEPRESENCE_GID`, a published port, and bind mounts. For details on the
`images` setting, see the [upstream configuration reference](https://telepresence.io/docs/reference/config).

### Start the daemon container by hand

This example starts the same daemon process that the CLI starts, so that you can see what the container needs. The
configuration directory is mounted read-only, and the daemon writes its logs to the cache directory:

```bash
mkdir -p tp-config tp-cache/logs && touch tp-config/config.yml
docker run --rm -d --name tp-daemon \
  --cap-add NET_ADMIN --device /dev/net/tun:/dev/net/tun --pid host \
  -p 127.0.0.1:4038:4038 \
  -e TELEPRESENCE_UID="$(id -u)" -e TELEPRESENCE_GID="$(id -g)" \
  -v "$PWD/tp-config:/root/.config/telepresence:ro" \
  -v "$PWD/tp-cache:/root/.cache/telepresence" \
  dhi.io/telepresence:<tag> userd \
  --config /root/.config/telepresence/config.yml \
  --name docker-test --address :4038 --embed-network --teleroute-port 4039
```

The daemon listens on port 4038 inside the container. The command publishes it on `127.0.0.1` only. The daemon writes
`tp-cache/logs/connector.log`, and it changes the owner of the files it writes to the user and group in
`TELEPRESENCE_UID` and `TELEPRESENCE_GID`. Create `tp-cache/logs` first, as the command does. If it does not exist, the
daemon creates it as root with mode `0700`, and your user cannot read the log. To stop the container, run:

```bash
docker stop tp-daemon
```

## Common telepresence use cases

### Install the traffic manager with the image

The image runs the `telepresence helm` commands. These commands install and remove the traffic manager in your cluster
with the Helm chart that is built into the CLI. The container needs a kubeconfig and network access to the Kubernetes
API server. This example mounts your kubeconfig to the default location for the user `root`, and uses the host network:

```bash
docker run --rm --network host -v "$HOME/.kube/config:/root/.kube/config:ro" \
  dhi.io/telepresence:<tag> helm install --set usage.enabled=false
```

The command prints `Traffic Manager installed successfully`. It installs the traffic manager in the `ambassador`
namespace from `ghcr.io/telepresenceio/tel2`, at the same version as the client. Your cluster must be able to pull that
image. To remove the traffic manager, run:

```bash
docker run --rm --network host -v "$HOME/.kube/config:/root/.kube/config:ro" \
  dhi.io/telepresence:<tag> helm uninstall
```

The kubeconfig must work without helper programs on the host. A kubeconfig that calls a program for authentication, such
as a cloud provider CLI, needs that program inside the container. The image does not contain such programs. For the
other `telepresence helm` options, see the [upstream documentation](https://telepresence.io/docs).

## Non-hardened images vs. Docker Hardened Images

These differences from `ghcr.io/telepresenceio/telepresence` affect how you run the image.

### The image runs as root

The image runs as the root user (uid 0) in all variants, as the upstream image does. It is not a nonroot image. The
daemon needs the `NET_ADMIN` capability and `/dev/net/tun` to build the tunnel to the cluster, and the CLI mounts your
host directories at fixed paths under `/root`. The daemon also changes the owner of the files it writes to your host
user, which is the reason for `TELEPRESENCE_UID` and `TELEPRESENCE_GID`. Because of this, the sections about nonroot
users in the following boilerplate do not apply to this image. The daemon needs `NET_ADMIN`. It also needs `CHOWN` and
`DAC_OVERRIDE` to write into directories that your host user owns. Docker grants both by default. If you start the
daemon with `--cap-drop ALL`, add all three: `--cap-add NET_ADMIN --cap-add CHOWN --cap-add DAC_OVERRIDE`. Give the
container only the capabilities and devices shown in this guide.

### Shell and package manager in runtime variants

The upstream image contains a busybox shell. The Debian runtime variants of this image do not contain a shell. The
Alpine runtime variants contain the busybox shell, because the `iptables` package depends on it. No runtime variant
contains a package manager. The `dev` variants contain `bash` and the system package manager. For example:

```bash
docker run --rm --entrypoint bash dhi.io/telepresence:<tag>-dev -c 'ls /etc/telepresence'
```

To debug a runtime container, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/).

### Client usage reporting is off

The upstream client sends anonymous usage reports to `usg.tada.se` by default. This image contains the empty file
`/etc/telepresence/usage-opt-out`. The Telepresence client treats this file as a switch that turns off its usage
reporting, and it overrides the `usage.enabled` setting. As a result, the daemon container does not report usage. To see
the effect, mount a kubeconfig and run `config view --client-only`:

```bash
docker run --rm -v "$HOME/.kube/config:/root/.kube/config:ro" \
  dhi.io/telepresence:<tag> config view --client-only
```

The command reads the kubeconfig but does not contact the cluster. The output shows `enabled: false` under `usage` in
`clientConfig`. Without `--client-only`, the command asks a running daemon, and it fails in a container that runs no
daemon.

The traffic manager that `telepresence helm install` deploys is a different image with its own setting, and it reports
usage by default. Pass `--set usage.enabled=false`, as in the example above, to turn it off. To turn usage reporting on
again for the client, build an image that does not contain the marker file, and use that image as `images.clientImage`.
You must remove the file from a `dev` image, because the Debian runtime image has no shell for the `RUN` step:

```dockerfile
FROM dhi.io/telepresence:<tag>-dev
RUN rm /etc/telepresence/usage-opt-out
```

For the settings and the data that the client reports, see the
[upstream configuration reference](https://telepresence.io/docs/reference/config).

### No file capability on the binary

The upstream binary has the file capability `cap_net_bind_service+ep`. In a container that drops all capabilities, the
kernel then refuses to start it. The binary in this image has no file capability, so it starts in that case. For
example, this command works:

```bash
docker run --rm --cap-drop ALL --cap-add NET_ADMIN dhi.io/telepresence:<tag> version
```

This example runs only the `version` command. The daemon needs more capabilities, as
[The image runs as root](#the-image-runs-as-root) describes.

### HOME is set

The image sets `HOME=/root`. The CLI reads the kubeconfig from `/root/.kube/config`, and the daemon reads its
configuration from `/root/.config/telepresence`.

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
