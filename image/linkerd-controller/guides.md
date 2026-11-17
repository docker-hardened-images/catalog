## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/linkerd-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-linkerd-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this linkerd-controller image

This Docker Hardened linkerd-controller image includes:

- `linkerd2-controller`: the image entrypoint, a single binary whose subcommands are the control plane components
  `destination`, `identity`, `proxy-injector`, `sp-validator` and `heartbeat`, and the `service-mirror` component of the
  Linkerd multicluster extension
- `linkerd-policy-controller`: the policy controller that runs next to the destination component

The binaries are also available at `/controller` and `/linkerd-policy-controller`, the same paths as the upstream image.

## Start a linkerd-controller image

Linkerd starts this image for you. The Linkerd Helm chart runs it for the `linkerd-destination`, `linkerd-identity` and
`linkerd-proxy-injector` deployments and for the `linkerd-heartbeat` job, and passes the component as the first
argument, for example `destination`. The `linkerd-destination` pod also runs the policy controller from this image with
`/linkerd-policy-controller` as its command. The Linkerd multicluster chart runs the image with `service-mirror` as the
first argument for its service mirror deployments.

### Use the image with the Linkerd Helm chart

Linkerd publishes its edge release charts in the `https://helm.linkerd.io/edge` repository. Add it, install the Linkerd
CRDs, and pass the image to the control plane chart. Create the trust anchor and issuer certificates as described in the
[Linkerd installation guide](https://linkerd.io/2/tasks/install-helm/):

```bash
$ helm repo add linkerd-edge https://helm.linkerd.io/edge
$ helm install linkerd-crds linkerd-edge/linkerd-crds --version 2026.10.1 \
  --namespace linkerd --create-namespace
$ helm install linkerd-control-plane linkerd-edge/linkerd-control-plane --version 2026.10.1 \
  --namespace linkerd \
  --set-file identityTrustAnchorsPEM=ca.crt \
  --set-file identity.issuer.tls.crtPEM=issuer.crt \
  --set-file identity.issuer.tls.keyPEM=issuer.key \
  --set controllerImage=dhi.io/linkerd-controller \
  --set controllerImageVersion=<tag>
```

Without `controllerImageVersion` the chart uses its own Linkerd release version, for example `edge-26.10.1`, which is
also a tag of this image. Set it to pin a different tag. Add `--set imagePullSecrets[0].name=<secret>` when the cluster
pulls from `dhi.io` with a pull secret. The chart version `2026.10.1` belongs to the `edge-26.10.1` release; use the
chart version of the release you deploy.

### Use the image with the Linkerd multicluster extension

The multicluster chart runs the controller image for the local service mirror and for the service mirror of each link.
Pass the image for both:

```bash
$ helm install linkerd-multicluster linkerd-edge/linkerd-multicluster --version 2026.10.1 \
  --namespace linkerd-multicluster --create-namespace \
  --set localServiceMirror.image.name=dhi.io/linkerd-controller \
  --set localServiceMirror.image.version=<tag> \
  --set controllerDefaults.image.name=dhi.io/linkerd-controller \
  --set controllerDefaults.image.version=<tag>
```

### Check the packaged release

The controller reports the Linkerd release it belongs to in the `LINKERD_CONTAINER_VERSION_OVERRIDE` environment
variable:

```bash
$ docker image inspect dhi.io/linkerd-controller:<tag> --format '{{range .Config.Env}}{{println .}}{{end}}' | grep LINKERD
```

## Common linkerd-controller use cases

### List the flags of a control plane component

Each subcommand of the controller prints its flags with `-h`:

```bash
$ docker run --rm dhi.io/linkerd-controller:<tag> destination -h
```

The subcommands are `destination`, `identity`, `proxy-injector`, `sp-validator`, `heartbeat` and `service-mirror`. Run
without a subcommand, the controller prints `expected a subcommand` and exits with status 1:

```bash
$ docker run --rm dhi.io/linkerd-controller:<tag>
```

### Run the policy controller

The policy controller reads the cluster it runs in through the in-cluster Kubernetes configuration, so it only starts
inside a pod. Outside a cluster it stops with an error about the missing in-cluster environment variable:

```bash
$ docker run --rm --entrypoint /linkerd-policy-controller dhi.io/linkerd-controller:<tag> \
  --default-opaque-ports=25,587,3306,4444,5432,6379,9300,11211
```

## Non-hardened images vs. Docker Hardened Images

- Tags carry the Linkerd release the image ships in, for example `edge-26.10.1`, and the release number, for example
  `26.10.1`. The upstream image is tagged with the Linkerd release only. The `26` tag moves to each new edge release of
  2026 and the `26.10` tag to each one of October 2026. Upstream edge releases can include breaking changes, so pin
  `edge-26.10.1` or `26.10.1` to stay on one release.
- The image runs as the nonroot user, UID 65532, where the upstream image runs as root unless the pod sets a user. The
  Linkerd chart sets `runAsUser` for its control plane pods, so Linkerd deployments are not affected.
- The image entrypoint is `/usr/local/bin/linkerd2-controller`. The upstream path `/controller` and the policy
  controller path `/linkerd-policy-controller` are symbolic links to the binaries.
- The upstream image ships `/linkerd/LICENSE`. This image does not.
- The upstream release links the policy controller statically against musl and uses the musl allocator. The Debian
  variants run it on glibc, and on `x86_64` it uses jemalloc. The Alpine variants run it dynamically linked against musl
  with the musl allocator. A different allocator can change memory use and throughput under load.
- The runtime variants contain no shell. Use the dev variants, or Docker Debug, to get one.

**linkerd-controller is an exception to the FIPS statement below.** The policy controller in the FIPS variants uses the
AWS-LC-FIPS 4.2.0 cryptographic module for TLS. The AWS-LC-FIPS 4.x module is in FIPS 140-3 validation and is not yet
validated, so the FIPS variants are FIPS compliant, not FIPS validated. The FIPS attestation lists the Go FIPS 140-3
module and the OpenSSL FIPS provider, not AWS-LC-FIPS. The controller binary uses the Go FIPS 140-3 module, and the
image installs the OpenSSL FIPS provider for operating system level cryptography.

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
