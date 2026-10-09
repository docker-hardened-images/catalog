## How to use this image

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
repository**, and then follow the on-screen instructions.

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Calico Third-Party CNI Plugins image

This Docker Hardened Calico Third-Party CNI Plugins image includes:

- host-local
- loopback
- portmap
- tuning
- flannel
- install-cni-plugins

## Stage plugins with the default entrypoint

The image entrypoint copies binaries from `/plugins/` into `/stage` (override with `-dst` or `STAGE_DIR`). The Tigera
Operator mounts an emptyDir at `/stage` for the `cni-plugins` init container.

```bash
docker run --rm --user 0 \
  -v cni-plugins-stage:/stage \
  dhi.io/third-party-cni-plugins:<tag>
```

The operator then runs `install-cni`, which reads the staged binaries from `/opt/cni/bin` (the same volume) and copies
them onto the host.

The image default user is `nonroot`. The Tigera Operator sets a root security context on the init container, so use
`--user 0` (as above) when you stage plugins outside the operator.

## Deploy with the Tigera Operator

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

Install the Tigera Operator, then set `Installation` so every Calico image, including `third-party-cni-plugins`, is
pulled from your DHI mirror. The operator resolves
`<registry><imagePath>/<imagePrefix>third-party-cni-plugins:<calico-version>` (for example `v3.33.0`).

```yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  imagePullSecrets:
    - name: dhi-pull-secret
  registry: dhi.io/
  imagePath: <your-namespace>
  imagePrefix: dhi-
  cni:
    type: Calico
```

Replace `<your-namespace>` with your organization's namespace. You can also pin digests with an `ImageSet` whose image
name is `calico/third-party-cni-plugins`.

If only this DHI image is mirrored, other Calico components may fail with `ImagePullBackOff` until their DHI images are
mirrored as well.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | Runtime variants run as `nonroot`. The Tigera Operator overrides the init container to root; for local staging use `--user 0` with a writable `/stage` volume.                                                                                                                                                               |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | The entry point is `/usr/local/bin/install-cni-plugins`, matching upstream `calico/third-party-cni-plugins`. Plugin binaries are at `/plugins/`.                                                                                                                                                                             |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

When deploying with the Tigera Operator, configure the `Installation` CR so the operator pulls
`dhi/third-party-cni-plugins` (and other Calico DHI images) instead of upstream `quay.io/calico/*` references.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

If the init container cannot write to `/stage`, check the volume mount and security context. Locally, stage with
`--user 0` and a writable volume at `/stage`.

### Privileged ports

Non-dev hardened images that run as nonroot can't bind to privileged ports (below 1024) when running in Kubernetes or in
Docker Engine versions older than 20.10. This image does not listen on a network port.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

The default entry point copies `/plugins/*` into `/stage`. Override `-src` / `-dst` only if your volume layout differs
from the operator's.
