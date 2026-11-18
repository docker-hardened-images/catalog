## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/consul-k8s-control-plane:<tag>`
- Mirrored image: `<your-namespace>/dhi-consul-k8s-control-plane:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Consul K8s Control Plane image

This image contains the three binaries that the official HashiCorp Consul Helm chart runs from its `global.imageK8S`
image: `consul-k8s-control-plane`, the `consul-cni` CNI plugin, and `discover`. They are installed in `/usr/bin` and are
also reachable at the upstream paths `/bin/consul-k8s-control-plane`, `/bin/consul-cni`, and `/bin/discover`. The image
also includes `nft` (`2` tags) or `iptables` (`1.8` and `1.7` tags), which the injected init container uses to set up
transparent proxy redirection when the Consul CNI plugin is not used.

Each tag line follows one consul-k8s release line: `2` ships consul-k8s 2.x, `1.8` (also tagged `1`) ships 1.8.x, and
`1.7` ships 1.7.x. Debian-based images use the plain tags, for example `2`, and Alpine-based images add `-alpine`, for
example `2-alpine`.

For configuration and deployment topologies, see the
[Consul on Kubernetes documentation](https://developer.hashicorp.com/consul/docs/k8s).

### Check the packaged version

The image has no entrypoint. As with the upstream image, pass the binary name as the first argument:

```bash
$ docker run --rm dhi.io/consul-k8s-control-plane:<tag> consul-k8s-control-plane version
consul-k8s-control-plane v<version>
```

Running the image without arguments starts `consul-k8s-control-plane` with no subcommand. It prints the list of
subcommands and exits with code 127, like the upstream image.

### Use the image with the Consul Helm chart

Point the official `hashicorp/consul` chart at this image with `global.imageK8S`. Use the chart version that matches the
consul-k8s version of the image, for example chart `2.1.0` with an image that prints `v2.1.0`:

```bash
$ helm repo add hashicorp https://helm.releases.hashicorp.com
$ helm install consul hashicorp/consul \
  --version <chart-version> \
  --create-namespace --namespace consul \
  --set global.imageK8S=dhi.io/consul-k8s-control-plane:<tag> \
  --set 'global.imagePullSecrets[0].name=<secret>'
```

The chart's own pods run this image, and the connect-inject webhook passes the same reference to the init container it
adds to every mesh pod. Application namespaces with mesh pods must therefore also be able to pull from `dhi.io`.
`connectInject.image` and `syncCatalog.image` override `global.imageK8S` for those components; leave them unset or set
them to the same image.

Keep the chart's security context as it is. The chart runs its containers as UID 100 with a read-only root filesystem,
and UID 100 (group 1000) is the user of the runtime images, as it is upstream. To check the image under those conditions
locally:

```bash
$ docker run --rm --user 100 --read-only dhi.io/consul-k8s-control-plane:<tag> \
  /bin/sh -ec 'exec consul-k8s-control-plane version'
consul-k8s-control-plane v<version>
```

## FIPS variants

FIPS images use `-fips` tags in this repository, for example `2-fips` or `2-alpine-fips`. To use one with the Helm
chart, set `global.imageK8S` to a `-fips` tag.

In the FIPS variants, `consul-k8s-control-plane`, `consul-cni`, and `discover` are built with the Go Cryptographic
Module and run in FIPS 140-3 mode by default. The OpenSSL FIPS provider is installed and configured.

On the `2` and `1.8` lines, the binaries also keep upstream's FIPS build behavior:

- `version` prints a `+fips1403` suffix.
- The API gateway enforces FIPS RSA key lengths for listener certificates.
- `connect-init` logs a warning when the Consul server is not a FIPS build.

```bash
$ docker run --rm dhi.io/consul-k8s-control-plane:<tag>-fips consul-k8s-control-plane version
consul-k8s-control-plane v<version>+fips1403
```

The `1.7` FIPS images do not have that behavior. Upstream's 1.7 FIPS image is a FIPS 140-2 BoringCrypto build, and its
FIPS build behavior requires BoringCrypto. The `1.7` FIPS images use the same Go Cryptographic Module and OpenSSL
provider as the other lines, but `version` prints no FIPS suffix, the API gateway does not enforce FIPS RSA key lengths,
and `connect-init` does not warn about a non-FIPS Consul server.

## Non-hardened images vs. Docker Hardened Images

- **User:** runtime images run as upstream's user `100` (UID 100, GID 1000, home `/home/100`), so a kubeconfig mounted
  at `/home/100/.kube/config` is still found. Dev images run as root, so Kubernetes refuses to start them in containers
  that set `runAsNonRoot` without a UID, such as the init container the webhook injects when transparent proxy is off.
- **Shell:** unlike most runtime images, this image's runtime variants include busybox as `/bin/sh`. The webhook and the
  gateway controllers start this image with `/bin/sh -ec`, and the chart uses `/bin/sh` in most containers. On Debian,
  busybox provides only `sh` and `sleep`. On Alpine, busybox provides its standard set of commands. The runtime images
  still have no package manager.
- **License notices:** license files are in `/usr/share/licenses/consul-k8s-control-plane/`, including the notices of
  bundled Go modules, instead of upstream's `/usr/share/doc/consul-k8s-control-plane/LICENSE.txt`.
- **FIPS:** upstream publishes FIPS images in a separate `hashicorp/consul-k8s-control-plane-fips` repository with
  `-fips1403` tags (`-fips1402` on 1.7). Here they are `-fips` tags in the same repository. See
  [FIPS variants](#fips-variants) for how the `1.7` FIPS images differ from upstream's.

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
