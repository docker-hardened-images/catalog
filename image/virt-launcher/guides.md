## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this virt-launcher image

This image bundles every binary upstream's virt-launcher container ships, plus the Debian system packages that KubeVirt
expects to find at runtime. It is intentionally **not** a minimal image; virt-launcher's job is to host an entire VM
runtime stack inside a single pod, and the upstream container is correspondingly large (~800MB-1GB).

**KubeVirt binaries shipped at `/usr/bin/`:**

- `virt-launcher`: VM supervisor that spawns the qemu process for one VirtualMachineInstance and proxies libvirt RPC.
- `virt-launcher-monitor`: parent process the KubeVirt operator runs as the pod entrypoint; supervises `virt-launcher`
  and carries the `cap_net_bind_service` file capability so qemu can bind privileged ports without an elevated pod.
- `virt-probe`: liveness/readiness probe binary the KubeVirt operator wires into VirtualMachineInstance pod specs.
- `virt-tail`: streams the qemu serial console log to the VM owner via `kubectl logs`.
- `virt-freezer`: issues qemu-guest-agent freeze/thaw commands so guest filesystems are quiesced before snapshots.
- `libvirt-hook-client`: Go binary that replaces the static `/etc/libvirt/hooks/qemu` shell hook when the
  `LibvirtHooksServerAndClient` feature gate is enabled.
- `container-disk`: tiny static C binary upstream embeds in customer-built ContainerDisk images to publish a VM disk
  over a unix socket. Shipped here so customers can `COPY --from=...` it.
- `node-labeller.sh`: shell script the KubeVirt operator runs once per node to detect hypervisor capabilities and
  publish them as node labels (used for scheduling decisions).

**Virtualization stack:**

- `qemu-system-x86_64` and supporting userland: the KVM hypervisor.
- `libvirtd` / `virtqemud`: connection manager that mediates between virt-launcher and qemu.
- `virtiofsd`: shared-filesystem daemon for VM disk and config mounts.
- `swtpm`, `swtpm-tools`: software TPM emulation.
- `passt`: userspace VM networking.
- `ovmf`, `seabios`, `ipxe-qemu`: UEFI / legacy / network boot firmware.
- `dmidecode`, `ethtool`, `numactl`, `numad`: hardware introspection used by `node-labeller.sh`.

KubeVirt extends Kubernetes with virtualization capabilities. The virt-launcher is one of several KubeVirt components
typically deployed by the KubeVirt operator. The companion images Docker Hardened Images ships are `dhi/virt-handler`,
`dhi/virt-controller`, `dhi/virt-api`, and `dhi/virt-operator`.

### A note on privileges

virt-launcher's runtime variant is **root-by-design**. Upstream needs root to start `libvirtd` / `virtqemud` and to
mediate access to `/dev/kvm`; the qemu process the daemon spawns drops to `uid 107` (the `qemu` user) before executing
guest code. The image therefore deviates from the usual Docker Hardened Images convention of running runtime variants as
the `nonroot` user. The KubeVirt operator wires the appropriate `securityContext.privileged` and `runAsUser: 0` settings
when it creates the VM pod.

### Run the virt-launcher container

The Virt Launcher is designed to run within a Kubernetes cluster as part of the KubeVirt operator deployment.

To display help information:

```bash
docker run --rm dhi.io/virt-launcher:<tag> --help
```

Verify the deployed version by inspecting the running KubeVirt pods in your cluster:

```bash
kubectl get pods -n kubevirt -l kubevirt.io=virt-launcher -o jsonpath='{.items[*].spec.containers[*].image}'
```

### Deploy KubeVirt in Kubernetes

The recommended way to deploy KubeVirt (including virt-launcher) is using the official KubeVirt operator manifests.
Replace `<version>` with the KubeVirt release you intend to run (it should match the virt-launcher version you are
standardizing on).

1. Install the KubeVirt operator:

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/<version>/kubevirt-operator.yaml
```

2. Create the KubeVirt custom resource:

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/<version>/kubevirt-cr.yaml
```

3. Verify the deployment:

```bash
kubectl get pods -n kubevirt
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Available image tags for virt-launcher:**

| Variant Type          | Tag Examples                             | Description                         |
| --------------------- | ---------------------------------------- | ----------------------------------- |
| **Standard (Debian)** | `<version>`, `<major>`                   | Runtime variants for production use |
|                       | `<version>-debian13`, `<major>-debian13` | Explicit Debian base specification  |

**Tag selection guidance:**

- Use `dhi.io/virt-launcher:<version>` for standard production deployments
- Use major version tags (like `:<major>`) for automatic minor updates (not recommended for production)

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
validated under FIPS 140, a U.S. government standard for secure cryptographic operations.

#### FIPS scope in virt-launcher specifically

virt-launcher is a fat image with both Go-side and C-side cryptography. In KubeVirt's default deployment configuration,
no cryptographic traffic terminates in the C-side code, so the `fips-compliant: true` attestation is meaningful:

- **Go side** (the KubeVirt binaries: virt-launcher, virt-launcher-monitor, virt-probe, virt-tail, virt-freezer,
  libvirt-hook-client): built against the Go FIPS 140 module with `GODEBUG=fips140=on`. Every TLS connection these
  binaries originate - to the Kubernetes API server, between virt-handler and virt-launcher, the CBT backup HTTP/2
  tunnel - uses FIPS-validated crypto. The mode is **lenient** (`fips140=on`) rather than strict (`fips140=only`)
  because the Kubernetes client-go dependency graph includes X25519 for TLS 1.3 key exchange and patching client-go is
  not tractable.

- **C side** (qemu, libvirt, virtiofsd, swtpm): these link against system crypto libraries that are **not** in FIPS
  mode. However, in KubeVirt 1.6 / 1.7 / 1.8 the shipped configuration explicitly disables every network-facing TLS
  endpoint in this code path:

  - `virtqemud.conf` ships with `listen_tls = 0` and `listen_tcp = 0`; the libvirt daemon only accepts connections on
    its local unix socket inside the pod.
  - `qemu.conf` ships with `vnc_tls = 0` and `vnc_sasl = 0`; VNC connections are plaintext and intended to be wrapped by
    an external proxy (typically virtctl over a websocket through the Kubernetes API).
  - Live VM migration uses a `qemu+unix:///` URI to a Go TLS proxy in `dhi/virt-handler` (a separate FIPS image), not
    qemu's own TLS migration. The qemu-to-qemu byte stream stays inside a unix socket; the network-facing TLS is Go's
    `crypto/tls`.

  Reference: upstream KubeVirt v1.8.2 `cmd/virt-launcher/virtqemud.conf`, `cmd/virt-launcher/qemu.conf`,
  `pkg/virt-launcher/virtwrap/live-migration-source.go`, `pkg/virt-handler/migration-proxy/migration-proxy.go`.

- **OpenSSL FIPS overlay**: the `-fips` variant overlays `dhi/pkg-openssl-fips` so that any libvirt or virtiofsd code
  path that loads libssl gets the FIPS provider for defence in depth. qemu and libvirt do not consume it via the OpenSSL
  FIPS provider mechanism in the deployed configuration, but the libraries are present and would be picked up if a
  customer ever enabled a TLS listener.

**Out of scope** — the following modes would route through non-FIPS C-side crypto and are not covered by this image's
FIPS attestation:

- Out-of-tree libvirt sidecars or custom configuration that re-enables qemu's TLS listener (`listen_tls = 1`).
- LUKS-encrypted backing volumes decrypted inside the qemu process. KubeVirt 1.8 does not support this path
  (`pkg/virt-launcher/` contains no LUKS code).
- VNC over TLS terminated directly in qemu (`vnc_tls = 1`).

For workloads operating KubeVirt in its default configuration, the `-fips` variant is suitable. For workloads that need
qemu-internal crypto to be FIPS-validated end to end (e.g. SEV-SNP with in-qemu attestation, or future LUKS support),
the FIPS gap is a known limitation — talk to Docker about the timeline for rebuilding qemu against the OpenSSL FIPS
provider.

**Runtime requirements specific to FIPS:**

- FIPS mode restricts cryptographic operations on the Go side to FIPS-validated algorithms.
- Usage of non-compliant operations (like MD5) on the Go side will fail.
- Larger image size due to FIPS-validated cryptographic libraries.

## Migrate to a Docker Hardened Image

virt-launcher is not consumed via Dockerfile - it is deployed by the KubeVirt operator. To switch an existing KubeVirt
installation to the hardened virt-launcher, patch the `KubeVirt` custom resource so the operator reaches into `dhi.io`
instead of `quay.io`. For example:

```yaml
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: kubevirt
spec:
  imageRegistry: dhi.io
  imageTag: "1.8"
  # ... existing config ...
```

After this change, the operator will roll out a new virt-handler DaemonSet whose pods pull `dhi.io/virt-launcher:1.8` as
the VM pod init image, replacing `quay.io/kubevirt/virt-launcher:v1.8.x`. No changes to your application VMs are
required; the next time a `VirtualMachineInstance` starts, it uses the hardened image.

The companion images need to be mirrored alongside virt-launcher so the operator can find them: `dhi/virt-handler`,
`dhi/virt-controller`, `dhi/virt-api`, `dhi/virt-operator`. All four are published with matching tags.

The rest of this section is the generic Docker Hardened Images migration guidance and applies primarily to images you
consume from a Dockerfile, not to virt-launcher specifically.

To migrate a Dockerfile-consumed image to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must
update the base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are
listed in the following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                               |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                               |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Debian-based images, you can use apt-get to install packages.

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
