## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/falco:<tag>`
- Mirrored image: `<your-namespace>/dhi-falco:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a falco image

Falco loads a **modern eBPF (CO-RE)** probe into the kernel to monitor syscalls. This requires elevated privileges and a
BTF-enabled kernel:

- **Privileges:** the documented minimum is `CAP_SYS_PTRACE`, `CAP_SYS_RESOURCE`, `CAP_BPF`, and `CAP_PERFMON`. Docker
  does not yet expose `CAP_BPF`/`CAP_PERFMON` directly, so the practical minimum with `docker run` is `CAP_SYS_ADMIN` in
  their place. For local experiments, `--privileged` is the simplest option.
- **Kernel:** Linux 4.14+ with BTF enabled (5.8+ recommended). Mount host BTF with `-v /sys:/sys:ro` (or more narrowly
  `-v /sys/kernel/tracing:/sys/kernel/tracing:ro`) so Falco can read it.

The image has no entrypoint — matching upstream — and uses `cmd: ["/usr/bin/falco"]`. It runs as root, since eBPF
instrumentation requires elevated kernel privileges.

```bash
$ docker run --rm --privileged -v /sys:/sys:ro -p 8765:8765 \
  dhi.io/falco:<tag>
```

Falco starts, loads its default rules, attaches its eBPF probe, and begins evaluating live syscall events against the
rules. A healthz endpoint is served on port 8765.

## Common falco use cases

### Run with least privilege instead of `--privileged`

Docker's `--privileged` flag grants far more than Falco needs. The documented least-privilege invocation is:

```bash
$ docker run --rm \
  --cap-drop all \
  --cap-add sys_admin \
  --cap-add sys_resource \
  --cap-add sys_ptrace \
  -v /sys/kernel/tracing:/sys/kernel/tracing:ro \
  -p 8765:8765 \
  dhi.io/falco:<tag>
```

`sys_admin` stands in for `CAP_BPF`/`CAP_PERFMON`, which Docker does not yet support granting directly.

### Supply custom rules

Mount a custom rules file into `/etc/falco/rules.d/` (loaded in addition to the default rules) or replace
`/etc/falco/falco_rules.local.yaml` for local overrides/additions:

```bash
$ docker run --rm --privileged -v /sys:/sys:ro \
  -v "$(pwd)/my-rules.yaml:/etc/falco/rules.d/my-rules.yaml:ro" \
  dhi.io/falco:<tag>
```

### Validate a rules file without starting the engine

Falco's rule-validation mode only parses rule file contents — no eBPF probe, no root required:

```bash
$ docker run --rm dhi.io/falco:<tag> falco -V /etc/falco/falco_rules.yaml
```

### Print the version and build info

`falco --version` uses Falco's offline inspector and does not require any special privileges:

```bash
$ docker run --rm dhi.io/falco:<tag> falco --version
```

### Deploy as a Kubernetes DaemonSet

Falco is typically deployed as a DaemonSet so one instance monitors each node. See the
[Falco Kubernetes documentation](https://falco.org/docs/setup/kubernetes/) and the official
[Falco Helm chart](https://github.com/falcosecurity/charts) for a complete manifest, including the
`securityContext.capabilities` equivalent of the least-privilege flags above.

## Scope of this image

- **Modern eBPF (CO-RE) only.** The legacy kernel-module and legacy-eBPF drivers are not built or shipped. Modern eBPF
  is bundled directly into the `falco` binary — no separate driver-loader step, no DKMS, no kernel headers needed on the
  host. If you require the legacy kernel-module driver, this image is not a drop-in replacement.
- **`container` plugin included, built from source.** Falco's default bundled rules file requires this plugin to load at
  all, so it is built from `falcosecurity/plugins` (rather than using upstream's pre-built binary) and shipped.
- **Debian-based only.** No musl/Alpine variant is provided: the required `container` plugin cannot be loaded on musl,
  and a Falco without its default detection rules would silently detect nothing. Upstream ships no musl container image
  either.
- **`falcoctl` not included.** Upstream's own image deletes it too; this image never builds or ships it.
- Rules are the release-paired default ruleset from `falco.org`; no additional source plugins (e.g. `k8saudit`) are
  bundled.

## Non-hardened images vs. Docker Hardened Images

Like the upstream `falcosecurity/falco` image, this image runs as root and requires eBPF privileges — these requirements
are inherent to syscall-level monitoring, not added by hardening. There is no `ENTRYPOINT`, matching upstream exactly
(`CMD` only); commands are invoked as `docker run dhi.io/falco:<tag> falco <args>`.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  > **Note:** Unlike most DHI runtime images, this image runs as **root** because loading an eBPF probe into the kernel
  > requires elevated privileges.

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. Falco uses OpenSSL only for its optional HTTP output channel and webserver TLS — the core
  syscall-capture and rule-evaluation path is not a cryptography consumer.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or deployment manifest. At
minimum, update the base image to a Docker Hardened Image. This and a few other common changes are listed below.

| Item               | Migration note                                                                                                                                                      |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base image reference with a Docker Hardened Image.                                                                                                     |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                         |
| Non-root user      | Most non-dev DHI images run as the nonroot user, but this image runs as **root** because loading an eBPF probe requires elevated privileges. This matches upstream. |
| Entry point        | This image has no `ENTRYPOINT`; invoke commands as `docker run dhi.io/falco:<tag> falco <args>`, matching upstream's own `CMD`-only Dockerfile.                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                  |
| Legacy driver      | This image ships modern eBPF only. If your deployment relies on the legacy kernel-module or legacy-eBPF driver, this image is not a drop-in replacement.            |
| No shell           | By default, non-dev images don't contain a shell. Use dev images in build stages, and Docker Debug to inspect running containers.                                   |

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging is [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/), which attaches an ephemeral, writable
debugging session to a running container.

### Falco fails to start / doesn't attach its probe

This is almost always a privilege or kernel-compatibility issue, not an image issue:

- Confirm the container has at least `CAP_SYS_PTRACE`, `CAP_SYS_RESOURCE`, and `CAP_SYS_ADMIN` (or is `--privileged`).
- Confirm the host kernel is 4.14+ with BTF enabled (`ls /sys/kernel/btf/vmlinux` on the host); mount `/sys` read-only
  into the container if the probe can't find it.
- Run `falco -V /etc/falco/falco_rules.yaml` (no special privileges required) first to rule out a rules/config issue
  before troubleshooting the eBPF attach path.

### Permissions

This image runs as root because eBPF instrumentation requires elevated kernel privileges — this is not something
hardening removes. Ensure the container runtime grants the capabilities described under
[Start a falco image](#start-a-falco-image).

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages, and Docker
Debug to debug containers with no shell.
