## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this forklift-virt-v2v image

This Docker Hardened forklift-virt-v2v image includes:

- `virt-v2v` - converts a VM guest disk image to run on QEMU/KVM
- `virt-customize` - customizes a guest disk image without booting it
- `guestfish` - interactive shell for inspecting and editing guest disk images
- Forklift's own Go helper binaries (`virt-v2v-wrapper`, `virt-v2v-monitor`, `image-converter`,
  `forklift-wait-for-reboot`) that drive and monitor a conversion started by Forklift itself

## Start a forklift-virt-v2v image

The default entrypoint, `virt-v2v-wrapper`, is driven entirely by environment variables that Forklift's own conversion
job sets. It isn't meant for standalone use, so a plain `docker run` against the default entrypoint exits immediately
with a configuration error. To confirm the image works, run the underlying `virt-v2v` tool directly with an explicit
entrypoint override:

```bash
$ docker run --rm --entrypoint virt-v2v dhi.io/forklift-virt-v2v:<tag> --version
```

## Common forklift-virt-v2v use cases

Anything that reads or writes a guest disk boots a small libguestfs appliance inside the container, so these examples
need two things that a plain `docker run` does not give you.

Pass `--device /dev/kvm` so the appliance can boot. Without it the appliance falls back to software emulation, which is
slow, and on arm64 it fails outright because libguestfs starts qemu with `-cpu host` and `gic-version=host`, and both
need KVM. If you have no `/dev/kvm` on the host, set `LIBGUESTFS_BACKEND_SETTINGS=force_tcg` to force emulation instead.

Make any path the tool writes to writable by the runtime user, which is UID 65532. That means the output directory in
the conversion examples, and the disk itself for `virt-customize`, since it edits in place. A read-only or root-owned
mount fails partway through the run.

### Convert a guest disk image

Convert a standalone qcow2 disk image so it boots correctly under QEMU/KVM. Mount the source disk read-only and an
output directory for the converted result:

```bash
$ docker run --rm \
  --device /dev/kvm \
  -v /path/to/source-disk.qcow2:/input/disk.qcow2:ro \
  -v /path/to/output:/output \
  --entrypoint virt-v2v \
  dhi.io/forklift-virt-v2v:<tag> \
  -i disk /input/disk.qcow2 -o local -os /output
```

### Convert a Windows guest disk image

Windows guests need VirtIO drivers so the converted guest can boot from virtio storage. The image ships them at
`/usr/share/virtio-win`, which is where virt-v2v looks by default, so the command is the same as for a Linux guest:

```bash
$ docker run --rm \
  --device /dev/kvm \
  -v /path/to/windows-disk.qcow2:/input/disk.qcow2:ro \
  -v /path/to/output:/output \
  --entrypoint virt-v2v \
  dhi.io/forklift-virt-v2v:<tag> \
  -i disk /input/disk.qcow2 -o local -os /output
```

Storage and network drivers are included for Windows 7 through Windows 11 and Server 2008 R2 through Server 2022, on
both x86 and x64. To use a different driver set, mount your own and point `VIRTIO_WIN` at it.

### Inspect a guest disk image

Use `guestfish` to open a disk image read-only and explore its filesystem without booting it:

```bash
$ docker run --rm -it \
  --device /dev/kvm \
  -v /path/to/disk.qcow2:/input/disk.qcow2:ro \
  --entrypoint guestfish \
  dhi.io/forklift-virt-v2v:<tag> \
  --ro -a /input/disk.qcow2 -i
```

### Customize a converted guest disk image

Use `virt-customize` to make configuration changes to a guest disk image (for example, running a script) without booting
the guest:

```bash
$ docker run --rm \
  --device /dev/kvm \
  -v /path/to/disk.qcow2:/input/disk.qcow2 \
  --entrypoint virt-customize \
  dhi.io/forklift-virt-v2v:<tag> \
  -a /input/disk.qcow2 --run-command 'echo customized > /etc/motd'
```

### Orchestrated migration through Forklift

In production, this image runs as a conversion step inside a Forklift-managed Kubernetes job, driven by Forklift's own
provider and plan CRDs rather than direct `docker run` invocations. For setting up providers, migration plans, and full
end-to-end VM migrations, see the [Forklift documentation](https://kubev2v.github.io/forklift-documentation/).

## Non-hardened images vs. Docker Hardened Images

This image's entrypoint binaries live at `/usr/local/bin/<name>` via a symlink; the packaged binary paths
(`/usr/bin/virt-v2v-wrapper`, `/usr/bin/virt-v2v-monitor`, and so on) remain available, so scripts that exec either path
keep working.

Upstream's own container runs virt-v2v against a `libvirt:qemu:///session` backend, which needs a running libvirtd
session. This image instead uses libguestfs's `direct` backend (`LIBGUESTFS_BACKEND=direct`), so virt-v2v drives QEMU
directly without a libvirt daemon in the container. libguestfs normally builds its appliance on demand via supermin,
which needs a real kernel at boot time; neither is available at runtime in a container, so this image ships a fixed
appliance built at image-build time instead (the same approach upstream's own container uses).

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
