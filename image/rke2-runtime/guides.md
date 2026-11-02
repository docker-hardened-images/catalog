## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this rke2-runtime image

This image is the runtime bundle that the `rke2` binary pulls and extracts onto every node. It has no entrypoint and is
not meant to run as a container. RKE2 extracts exactly two directories from it:

- `/bin`: `containerd`, `containerd-shim-runc-v2`, `ctr`, `runc`, `crictl`, `kubelet` and `kubectl`, all statically
  linked so they run on any Linux host regardless of its libc.
- `/charts`: one `HelmChart` manifest per bundled add-on (`rke2-cilium`, `rke2-canal`, `rke2-calico`, `rke2-coredns`,
  `rke2-ingress-nginx`, `rke2-traefik`, `rke2-metrics-server`, `rke2-multus`, `rke2-flannel`,
  `rke2-snapshot-controller`, `rke2-runtimeclasses`, the Harvester, vSphere and oVirt providers and their CRD
  companions), each embedding the chart tarball that RKE2 deploys.

## Start a rke2-runtime image

### Use the image as the RKE2 runtime image

Set the `runtime-image` option in the RKE2 configuration file on every server and agent node before starting the
`rke2-server` or `rke2-agent` service:

```yaml
# /etc/rancher/rke2/config.yaml
runtime-image: dhi.io/rke2-runtime:<tag>
```

Pin the image by digest (`dhi.io/rke2-runtime@sha256:<digest>`). RKE2 names the directory it extracts the runtime into
after the image reference and skips extraction once that directory exists, so a node bootstrapped on a tag keeps the
binaries it first extracted and never picks up a rebuild published under the same tag. An existing node only sees a
rebuild when its `runtime-image` reference changes. RKE2 also accepts a tag that starts with `v`, so this repository's
`v<version>` tags (`v1.37.1`, `v1.37.1-rke2r1`) work where a digest is impractical; the `1.37.1-alpine` style tags are
rejected by RKE2.

The same option is available as the `--runtime-image` flag and the `RKE2_RUNTIME_IMAGE` environment variable:

```bash
$ rke2 server --runtime-image dhi.io/rke2-runtime:<tag>
```

RKE2 pulls the runtime image with the credentials configured in its private registry configuration. Add a `dhi.io` entry
so the node can pull from Docker Hardened Images:

```yaml
# /etc/rancher/rke2/registries.yaml
configs:
  dhi.io:
    auth:
      username: <docker-username>
      password: <docker-access-token>
```

Pick the `<tag>` whose Kubernetes minor version matches the `rke2` binary installed on the node. For example, use a
`v1.36.x` tag with an RKE2 `v1.36.x` release.

### Preload the image on air-gapped nodes

RKE2 loads the runtime image from a tarball placed in its agent images directory instead of pulling it from a registry:

```bash
$ docker pull dhi.io/rke2-runtime:<tag>
$ docker save -o rke2-runtime.tar dhi.io/rke2-runtime:<tag>
```

Copy `rke2-runtime.tar` to `/var/lib/rancher/rke2/agent/images/` on the node, keep the `runtime-image` option set to the
same `v<version>` tag (RKE2 matches preloaded tarballs by tag, not by digest), and start RKE2. The remaining RKE2 system
images still need the standard air-gap image bundle from the RKE2 release.

## Common rke2-runtime use cases

### Inspect the bundled binaries

The image has no entrypoint, so pass a bundled binary as the command to check the versions RKE2 will install on the
node:

```bash
$ docker run --rm dhi.io/rke2-runtime:<tag> /bin/kubelet --version
$ docker run --rm dhi.io/rke2-runtime:<tag> /bin/kubectl version --client
$ docker run --rm dhi.io/rke2-runtime:<tag> /bin/containerd --version
$ docker run --rm dhi.io/rke2-runtime:<tag> /bin/runc --version
```

`crictl --version`, `ctr --version` and `containerd-shim-runc-v2 -v` print a version line without a version stamp
(`crictl version unknown`, a bare `v` for `ctr` and the shim); check their versions through the `cri-tools` and
`containerd` entries in the image SBOM instead.

### Extract the bundle without RKE2

Copy the two directories RKE2 would extract, for example to audit the binaries or the chart manifests:

```bash
$ docker create --name rke2-runtime dhi.io/rke2-runtime:<tag> /bin/kubelet
$ docker cp rke2-runtime:/bin ./rke2-bin
$ docker cp rke2-runtime:/charts ./rke2-charts
$ docker rm rke2-runtime
```

Each file under `./rke2-charts` is a `HelmChart` manifest whose `spec.chartContent` field holds the base64-encoded chart
tarball.

## Non-hardened images vs. Docker Hardened Images

- The binaries are Docker Hardened Images builds of the upstream containerd, runc, cri-tools and Kubernetes projects
  instead of Rancher's `hardened-*` builds. `kubelet --version` reports the upstream Kubernetes version (for example
  `v1.37.1`) without the `+rke2rN` suffix, and the FIPS variant uses the Go FIPS 140-3 module instead of BoringCrypto.
- containerd is built from the upstream repository rather than the k3s-io fork, so it lacks the fork's additions:
  `rewrite` rules under `mirrors` in `registries.yaml`, which RKE2 writes into `hosts.toml`, are ignored by upstream
  containerd.
- containerd, runc and crictl follow the newest Docker Hardened Images package, so their versions can be newer than the
  RKE2 release pins (`crictl` 1.37 alongside `kubelet` 1.36 is supported by the cri-tools compatibility matrix, which
  pairs any cri-tools 1.27+ release with any Kubernetes 1.27+ release). `crictl --version`, `ctr --version` and
  `containerd-shim-runc-v2 -v` print a version line without a version stamp; the image SBOM carries the package
  versions.
- The chart manifests are generated from the same chart versions as the RKE2 release. The embedded chart tarballs are
  repacked, so their bytes differ from upstream while their contents are identical.
- The image is built on the Docker Hardened Images Alpine base and runs as the nonroot user, so it also contains the
  base filesystem, CA certificates and time zone data. RKE2 only extracts `/bin` and `/charts`, so this does not change
  what is installed on the node.
- The image ships `linux/amd64` and `linux/arm64` only. The upstream tag also serves `windows/amd64` for RKE2 Windows
  agents, which keep using the upstream image.
- Tags follow the Docker Hardened Images scheme (`1.37.1-alpine`) plus `v<version>` (`v1.37.1`) and
  `v<version>-<rke2 revision>` (`v1.37.1-rke2r1`, the upstream image tag; the upstream release tag is `v1.37.1+rke2r1`).
  Always set `runtime-image` explicitly, preferably by digest; RKE2 does not derive this image's reference from its own
  version.

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

- FIPS variants include `fips` in the variant name and tag. This image ships the FIPS variant as a runtime variant only.
  These variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for
  secure cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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
