## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Hubble Relay Hardened Image

This Docker Hardened Hubble Relay image includes the relay server component of Cilium Hubble. The relay service
aggregates flow data from multiple Hubble instances across a cluster or multiple clusters, providing a centralized gRPC
API for querying network flows and observability data. It enables scalable Hubble deployments and cross-cluster
visibility.

### Start a Hubble Relay image

Hubble Relay requires TLS certificates by default. For testing without TLS, use the `--disable-server-tls` and
`--disable-client-tls` flags:

```bash
docker run --name hubble-relay -p 4245:4245 -p 4222:4222 \
  dhi.io/hubble-relay:<tag> serve \
  --disable-server-tls --disable-client-tls \
  --peer-service hubble.cilium.svc.cluster.local:4244
```

For production deployments, configure TLS certificates by mounting certificate files and using the TLS flags:

```bash
docker run --name hubble-relay -p 4245:4245 -p 4222:4222 \
  -v /path/to/certs:/etc/certs:ro \
  dhi.io/hubble-relay:<tag> serve \
  --tls-relay-server-cert-file /etc/certs/server.crt \
  --tls-relay-server-key-file /etc/certs/server.key \
  --peer-service hubble.cilium.svc.cluster.local:4244
```

> **Note:** Replace `/path/to/certs` with the path to your certificate directory. Certificates can be generated
> manually, provided by cert-manager in Kubernetes, or obtained from your certificate authority.

## Common use cases

### Install Cilium with Hubble Relay using Helm

You can install Cilium with Hubble Relay using the official Helm chart and replace the relay image. Replace
`<your-registry-secret>` with your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/) and `<tag>`
with the desired image tag.

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --set hubble.relay.enabled=true \
  --set "imagePullSecrets[0].name=<your-registry-secret>" \
  --set hubble.relay.image.override="<IMAGE_REPOSITORY>:<IMAGE_TAG>" \
  --set hubble.relay.securityContext.enabled=true \
  --set hubble.relay.securityContext.runAsNonRoot=true \
  --set hubble.relay.securityContext.runAsUser=65532 \
  --set hubble.relay.securityContext.runAsGroup=65532
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Hubble Relay      | Docker Hardened Hubble Relay                        |
| --------------- | ------------------------------ | --------------------------------------------------- |
| Security        | Standard base with utilities   | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available | No shell in runtime variants                        |
| Package manager | apt/apk available              | No package manager in runtime variants              |
| User            | Runs as root by default        | Runs as nonroot user                                |
| Attack surface  | Larger due to utilities        | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging    | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/hubble-relay:<tag>
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

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

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

Switching to the hardened Hubble Relay image does not require any special changes. You can use it as a drop-in
replacement for the standard Hubble Relay (`cilium/hubble-relay`) image in your existing workflows and configurations.
Note that the entry point for the hardened image may differ from the standard image, so ensure that your commands and
arguments are compatible.

### Migration steps

1. Replace the image reference in your Docker run command or Compose file.

1. All your existing command-line arguments, environment variables, port mappings, and network settings remain the same.

1. Test your migration and use the troubleshooting tips below if you encounter any issues.

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
