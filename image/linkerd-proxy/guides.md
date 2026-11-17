## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/linkerd-proxy:<tag>`
- Mirrored image: `<your-namespace>/dhi-linkerd-proxy:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this linkerd-proxy image

This Docker Hardened linkerd-proxy image includes:

- `linkerd2-proxy`: the Linkerd data plane proxy
- `linkerd2-proxy-identity`: the image entrypoint, which generates the proxy key and certificate signing request and
  then starts the proxy
- `linkerd-await`: waits for the proxy to become ready before it runs a command
- `linkerd2-proxy-init`: the init container binary that redirects pod traffic through the proxy
- `linkerd2-network-validator`: the init container tool that checks the traffic redirection
- `iptables`: the packet filtering tools that `linkerd2-proxy-init` drives

All Linkerd binaries are available under `/usr/lib/linkerd/`, the same paths as the upstream image.

## Start a linkerd-proxy image

Linkerd starts this image for you. The proxy injector adds it to your pods as the `linkerd-proxy` sidecar, and the same
image runs the `linkerd-init` and `linkerd-network-validator` init containers. The Linkerd Helm chart reads the image
from `proxy.image.name` and `proxy.image.version`, and the init containers use the same values.

### Use the image with the Linkerd Helm chart

Install the Linkerd CRDs and the control plane as described in the
[Linkerd installation guide](https://linkerd.io/2/getting-started/), and pass the image to the control plane chart:

```bash
$ helm install linkerd-control-plane linkerd/linkerd-control-plane \
  --set-file identityTrustAnchorsPEM=ca.crt \
  --set-file identity.issuer.tls.crtPEM=issuer.crt \
  --set-file identity.issuer.tls.keyPEM=issuer.key \
  --set proxy.image.name=dhi.io/linkerd-proxy \
  --set proxy.image.version=<tag>
```

Without `proxy.image.version` the chart uses its own Linkerd release version, for example `edge-26.10.1`, which is also
a tag of this image. Set it to pin a different tag. Add `--set imagePullSecrets[0].name=<secret>` when the cluster pulls
from `dhi.io` with a pull secret.

### Check the packaged proxy release

The proxy logs its release when it starts. Run the binary through its upstream path to read it:

```bash
$ docker run --rm --entrypoint /usr/lib/linkerd/linkerd2-proxy dhi.io/linkerd-proxy:<tag>
```

The first line names the release, the commit and the builder:

```text
INFO ThreadId(01) linkerd2_proxy: release 2.370.0 (0cdcc07) by dhi on <build date>
```

The proxy then stops with `Invalid configuration`, because a running proxy needs the environment variables that
Linkerd's injector sets.

## Common linkerd-proxy use cases

### Preview the iptables rules proxy-init installs

`linkerd2-proxy-init` carries file capabilities, so run it with the `NET_ADMIN` and `NET_RAW` capabilities. `--simulate`
prints the commands without running them:

```bash
$ docker run --rm --cap-add NET_ADMIN --cap-add NET_RAW \
  --entrypoint /usr/lib/linkerd/linkerd2-proxy-init \
  dhi.io/linkerd-proxy:<tag> \
  --simulate --iptables-mode nft --proxy-uid 2102 \
  --incoming-proxy-port 4143 --outgoing-proxy-port 4140 --ipv6=false
```

The output starts with the `iptables-nft` commands that create the `PROXY_INIT_REDIRECT` chain.

### Validate the pod network

`linkerd2-network-validator` binds a listener and connects to it. It prints `Validated` and exits 0 when the connection
arrives:

```bash
$ docker run --rm --entrypoint /usr/lib/linkerd/linkerd2-network-validator \
  dhi.io/linkerd-proxy:<tag> \
  --listen-addr 127.0.0.1:4140 --connect-addr 127.0.0.1:4140 --timeout 5s
```

### Wait for the proxy before starting an application

`linkerd-await` polls the proxy admin port, `4191` by default, and runs the command once the proxy is ready. It exits 69
when the proxy is not ready within `--timeout`:

```bash
$ docker run --rm --entrypoint /usr/lib/linkerd/linkerd-await \
  dhi.io/linkerd-proxy:<tag> --timeout 2s -- /usr/lib/linkerd/linkerd2-proxy
```

## Non-hardened images vs. Docker Hardened Images

- Tags carry both the proxy release, for example `2.370.0-debian13`, and the Linkerd release it ships in, for example
  `edge-26.10.1-debian13`. The upstream image is tagged with the Linkerd release only.
- The image runs as the nonroot user, UID 65532, where the upstream image runs as UID 65534. Pods that Linkerd injects
  set `runAsUser` themselves, so meshed pods are not affected.
- The `linkerd2-proxy-init` legacy iptables mode takes a lock on `/run/xtables.lock`, and `/run` is not writable by the
  nonroot user. The Linkerd chart mounts a writable volume on `/run` for the init container, as it does for the upstream
  image. When you run it yourself in legacy mode, mount one, for example `--tmpfs /run:rw,uid=65532,gid=65532`.
- `linkerd2-proxy-init` needs the `NET_ADMIN` and `NET_RAW` capabilities, as in the upstream image.
- The upstream image ships `/usr/lib/linkerd/linkerd2-proxy-version.txt` and `/usr/lib/linkerd/LICENSE`. This image
  ships neither; the proxy reports its release in its startup log.
- The Debian variants run the proxy on glibc. On `x86_64` the proxy uses jemalloc, as the upstream release does. The
  Alpine variants run it on musl with the musl allocator, which can change memory use and throughput under load.
- The `iptables` and `ip6tables` tools are the distribution's packages, not the Wolfi build the upstream image uses. The
  image does not include `getcap` or `capsh`.
- The Debian runtime variants contain no shell. Use the dev variants, or Docker Debug, to get one.
- The upstream image ships `/bin/sleep`, which the Linkerd chart's `preStop` hook runs when
  `proxy.waitBeforeExitSeconds` is set and `proxy.nativeSidecar` is false. The Debian runtime variants include only the
  `sleep` binary from Debian's `coreutils`, and the Alpine runtime variants provide it through BusyBox.
- The upstream image ships the `nft` command. This image ships it only in the dev variants, because
  `linkerd2-proxy-init` programs nftables through `iptables-nft` and never runs `nft`. Use a dev variant to inspect the
  installed rules with `nft list ruleset`.

**linkerd-proxy is an exception to the no-shell statements below on Alpine.** The Alpine runtime variants include
BusyBox, with `/bin/sh` and its applets such as `wget`, because the Alpine `iptables` package that `linkerd2-proxy-init`
drives depends on `/bin/sh`.

**linkerd-proxy is an exception to the FIPS statement below.** The proxy in the FIPS variants uses the AWS-LC-FIPS 4.1.0
cryptographic module for TLS. The AWS-LC-FIPS 4.x module is in FIPS 140-3 validation and is not yet validated, so the
FIPS variants are FIPS compliant, not FIPS validated. The FIPS attestation lists the Go FIPS 140-3 module and the
OpenSSL FIPS provider, not AWS-LC-FIPS. The identity and init binaries use the Go FIPS 140-3 module, and the image
installs the OpenSSL FIPS provider for operating system level cryptography.

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
