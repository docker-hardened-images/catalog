## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this forklift-controller image

This Docker Hardened Forklift Controller image is a component of the [Forklift](https://github.com/kubev2v/forklift) VM
migration operator for KubeVirt.

- `forklift-controller`: reconciles Forklift providers, plans, mappings, hooks, and migrations, and drives each virtual
  machine migration from inventory discovery through disk transfer

Forklift migrates virtual machines from VMware vSphere, oVirt, OpenStack, Hyper-V, EC2, and OVA sources to KubeVirt. The
controller is one of several Forklift components and is normally deployed by the Forklift operator as part of a full
Forklift installation.

### Key differences

| Feature         | Upstream forklift-controller           | Docker Hardened forklift-controller                                 |
| --------------- | -------------------------------------- | ------------------------------------------------------------------- |
| Base image      | UBI 9 minimal                          | Minimal, hardened Debian or Alpine base                             |
| Shell access    | Full shell available                   | No shell in runtime variants                                        |
| Package manager | `microdnf` available                   | No package manager in runtime variants                              |
| User            | Runs as root by default                | Runs as the nonroot user                                            |
| `tar`           | Installed to copy files out of the pod | Not installed in runtime variants                                   |
| Binary path     | `/usr/local/bin/forklift-controller`   | `/usr/bin/forklift-controller`, with a symlink at the upstream path |

The upstream image installs `tar` so that files can be copied out of a running pod, for example with `kubectl cp` or
during a must-gather. It is omitted from the hardened runtime variants to keep the attack surface minimal. If you need
to retrieve files from a running container, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/), or
use the `dev` variant, which includes a shell and a package manager.

### Run the forklift-controller container

The controller is designed to run inside a Kubernetes cluster with access to the Kubernetes API and to the Forklift
custom resources. Running it standalone is useful mainly to verify the image starts.

The `ROLE` environment variable selects which roles the controller runs. It accepts `main`, `inventory`, or a
comma-separated combination. When `ROLE` is unset, both roles are enabled.

The `main` role requires the migration settings that the Forklift operator normally injects, so the shortest way to
check the image is to start the inventory role only:

```bash
docker run --rm -e ROLE=inventory dhi.io/forklift-controller:<tag>
```

Without a reachable cluster the controller logs its metrics and profiling endpoints, then exits when it cannot load a
kube config. That is the expected standalone behavior.

### Ports

This image changes none of the controller's defaults, so it listens exactly where the upstream image does. Only `2112`
is declared on the image, because it is the only port the controller binds unconditionally; the other two depend on
`ROLE` and on the port variables below.

| Port   | Description                                                 |
| ------ | ----------------------------------------------------------- |
| `8080` | Inventory API, overridable with `API_PORT`                  |
| `8080` | Controller manager metrics, overridable with `METRICS_PORT` |
| `2112` | Prometheus metrics at `/metrics`, plus Go pprof handlers    |

`API_PORT` and `METRICS_PORT` both default to `8080`, so on the bare defaults the inventory API and the controller
manager metrics server compete for the same socket. Whichever binds second fails with
`listen tcp :8080: bind: address already in use` and the controller exits. This is upstream behavior, not something this
image introduces.

A normal Forklift install never hits it because the operator sets both ports explicitly: its `main` container gets
`API_PORT=8443` and `METRICS_PORT=8081`, and its `inventory` container gets `API_PORT=8443` and `METRICS_PORT=8082`. Use
the same values if you deploy the container yourself:

```yaml
env:
  - name: ROLE
    value: inventory
  - name: API_PORT
    value: "8443"
  - name: METRICS_PORT
    value: "8082"
```

The inventory API serves plain HTTP unless you also set `API_TLS_CERTIFICATE` and `API_TLS_KEY`, which is what the
operator mounts from its TLS secret.

Port `2112` is served by Go's default HTTP mux, and the controller imports `net/http/pprof`, so that listener exposes
the `/debug/pprof` handlers alongside `/metrics`. This is upstream behavior and is not configurable through the image.
Treat `2112` as a privileged debug port: keep it inside the cluster, and do not publish it to untrusted networks. The
same handlers are also reachable on port `6060`, which the controller binds to localhost inside the container only.

### Deploy Forklift in Kubernetes

The recommended way to deploy Forklift, including the controller, is with the Forklift operator. See the
[Forklift documentation](https://kubev2v.github.io/forklift-documentation/) for installation instructions and for the
provider, mapping, plan, and migration resources the controller reconciles.

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
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use `dev` images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
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
