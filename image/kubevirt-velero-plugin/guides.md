## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kubevirt-velero-plugin:<tag>`
- Mirrored image: `<your-namespace>/dhi-kubevirt-velero-plugin:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What this image does

This image carries the [KubeVirt Velero Plugin](https://github.com/kubevirt/kubevirt-velero-plugin). The plugin adds
Velero backup and restore actions for KubeVirt resources: VirtualMachines, VirtualMachineInstances, DataVolumes,
PersistentVolumeClaims, virt-launcher pods, and NetworkAttachmentDefinitions. For what each action does, see the
upstream project.

The image is not a long-running service. Velero runs it as an initContainer with a `plugins` volume mounted at
`/target`. The container copies the plugin binary into `/target` and exits. The Velero server then runs
`/plugins/kubevirt-velero-plugin` from that shared volume as a child process of its own container. You never run the
plugin as a separate Deployment.

## Choose the plugin line for your Velero version

Each plugin release line is built and tested against one Velero minor version. Use the matching line:

| Velero version | Hardened Velero image | KubeVirt Velero Plugin image        | Velero plugin for AWS image         |
| -------------- | --------------------- | ----------------------------------- | ----------------------------------- |
| 1.18.x         | `dhi.io/velero:1.18`  | `dhi.io/kubevirt-velero-plugin:0.9` | `dhi.io/velero-plugin-for-aws:1.14` |
| 1.16.x         | `dhi.io/velero:1.16`  | `dhi.io/kubevirt-velero-plugin:0.8` | `dhi.io/velero-plugin-for-aws:1.12` |

The bare `0` tag follows the newest plugin line (0.9). Pin `0.9` or `0.8` so that a new plugin line doesn't replace the
one that matches your Velero server.

Velero also needs an object storage plugin, such as the AWS plugin in the table. The KubeVirt plugin only handles
KubeVirt resources.

## Install the plugin with Velero

Your cluster must be able to pull images from `dhi.io` or from your mirror. See
[Authentication for Docker Hardened Images in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/).

### Install with the Velero CLI

Pass the plugin image to `velero install` with `--plugins`, next to your object storage plugin. The following example
installs the hardened Velero 1.18 server with the AWS plugin and the KubeVirt plugin. Replace the bucket, credentials
file, and backup location settings with your own:

```bash
velero install \
  --image dhi.io/velero:1.18 \
  --plugins dhi.io/velero-plugin-for-aws:1.14,dhi.io/kubevirt-velero-plugin:0.9 \
  --provider aws \
  --bucket velero-backups \
  --secret-file ./credentials-velero \
  --backup-location-config region=us-east-1
```

The `dhi.io/velero` image contains the `velero` CLI, so you can also run that command with
`docker run --rm dhi.io/velero:1.18 velero install ...`. Mount your kubeconfig and credentials file into the container
when you do.

To add the plugin to a Velero server that's already installed, run:

```bash
velero plugin add dhi.io/kubevirt-velero-plugin:0.9
```

Adding a plugin restarts the Velero server pod, so the command asks for confirmation. Add `--confirm` to skip the
prompt.

### Install with the Velero Helm chart

The Velero Helm chart adds plugins through its `initContainers` value. Each entry needs a name, the image, and the
chart's `plugins` volume mounted at `/target`. Add the KubeVirt plugin next to your object storage plugin:

```yaml
initContainers:
  - name: velero-plugin-for-aws
    image: dhi.io/velero-plugin-for-aws:1.14
    volumeMounts:
      - mountPath: /target
        name: plugins
  - name: kubevirt-velero-plugin
    image: dhi.io/kubevirt-velero-plugin:0.9
    volumeMounts:
      - mountPath: /target
        name: plugins
```

The same values work with the upstream
[Velero chart](https://github.com/vmware-tanzu/helm-charts/tree/main/charts/velero) and with the Docker Hardened Velero
chart (`oci://dhi.io/velero-chart`). Don't set `command` or `args` on these entries. The next section explains why.

### Verify the plugin

After the Velero pod restarts, list the registered plugins:

```bash
velero plugin get
```

The output lists the KubeVirt actions under names that start with `kubevirt-velero-plugin/`, such as
`kubevirt-velero-plugin/backup-virtualmachine-action` and `kubevirt-velero-plugin/restore-vm-action`. The 0.9 line
registers 12 actions and the 0.8 line registers 9. The 0.9 line adds `backup-pvc-action`,
`backup-volumesnapshot-action`, and `restore-volumesnapshot-action`.

No other configuration is needed. With the plugin registered, Velero applies its actions to every backup and restore
that includes KubeVirt resources. For example, the plugin skips virt-launcher pods on restore, and it backs up a running
VirtualMachineInstance together with its launcher pod.

## Don't set command or args

The image entrypoint runs the purpose-built `cp-plugin` helper directly, in exec form:

```json
["cp-plugin", "/plugins/kubevirt-velero-plugin", "/target/kubevirt-velero-plugin"]
```

The upstream image ran `/bin/sh -c "cp /plugins/* /target/."` instead, which ignored any arguments added to the
container. In this image, arguments are passed to `cp-plugin`. For example, `args: ["--foo"]` runs
`cp-plugin /plugins/kubevirt-velero-plugin /target/kubevirt-velero-plugin --foo`. The copy then fails, so the
initContainer fails and the Velero pod doesn't start.

Velero, `velero plugin add`, and the Velero Helm chart set no command or args on plugin initContainers, so the default
installs work unchanged. If you write the initContainer yourself:

- Leave `command` and `args` unset.
- To copy the plugin to a different location, mount your volume at `/target`. Don't change the arguments.
- Remove any `command: ["/bin/sh", "-c", ...]` override. The runtime image has no shell, so the container fails to start
  with `exec: "/bin/sh": stat /bin/sh: no such file or directory`.

## Copy the plugin binary without Velero

Running the image outside Velero copies the plugin binary into whatever directory is mounted at `/target`. The image
runs as UID `65532`, so the mounted directory must be writable by that user. To copy the binary into a local directory
that you own, run the container as your own user:

```bash
mkdir plugins
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/plugins:/target" dhi.io/kubevirt-velero-plugin:0.9
```

The command exits with status `0` and leaves an executable `plugins/kubevirt-velero-plugin`. If nothing is mounted at
`/target`, or the directory isn't writable, `cp-plugin` panics and the container exits with status `2`.

The plugin binary isn't meant to run on its own. When you run it directly, it prints
`This binary is a plugin. These are not meant to be executed directly.` and exits.

## Non-hardened images vs. Docker Hardened Images

| Item       | Upstream `quay.io/kubevirt/kubevirt-velero-plugin`   | Docker Hardened `dhi.io/kubevirt-velero-plugin`                                                        |
| ---------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Entrypoint | `/bin/sh -c "cp /plugins/* /target/."`, ignores args | `cp-plugin /plugins/kubevirt-velero-plugin /target/kubevirt-velero-plugin`, passes args to `cp-plugin` |
| User       | `nobody` (UID `65534`)                               | `65532` in runtime and FIPS variants, root in dev variants                                             |
| Shell      | BusyBox `/bin/sh`                                    | None in runtime and FIPS variants                                                                      |
| Platforms  | `linux/amd64`                                        | `linux/amd64` and `linux/arm64`                                                                        |

The different UID doesn't affect Velero installs. Velero backs the `plugins` volume with an `emptyDir`, which any user
can write to. The copied binary has mode `0755`, so the Velero server can run it even though it runs as a different
user. If you replace the `emptyDir` with another volume type, make sure UID `65532` can write to it.

The initContainer writes only to `/target`, so it also works with `readOnlyRootFilesystem: true`.

### Dev variants

Dev variants, such as `dhi.io/kubevirt-velero-plugin:0.9-dev`, run as root and add `bash` and the distribution's package
manager (`apt` on Debian, `apk` on Alpine). They keep the same `cp-plugin` entrypoint. Use them to inspect the image
with a shell, not in your Velero deployment:

```bash
docker run --rm --entrypoint bash dhi.io/kubevirt-velero-plugin:0.9-dev -c 'ls -l /plugins/'
```

### FIPS variants

The `-fips` variants, such as `dhi.io/kubevirt-velero-plugin:0.9-fips`, ship a plugin binary built with the Go FIPS
140-3 module, with FIPS mode on by default. The module is compiled into the plugin binary, so it moves with the binary
into the Velero server container. The plugin's TLS connections to the Kubernetes API use the Go FIPS module, no matter
which Velero server image runs the plugin. No extra configuration is needed.

The FIPS images also include OpenSSL with the FIPS provider for compliance scanning. The `cp-plugin` entrypoint performs
no cryptography. If your whole Velero deployment must use FIPS-validated cryptography, pair the FIPS plugin with the
FIPS variants of the Velero server and object storage plugin images.

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
