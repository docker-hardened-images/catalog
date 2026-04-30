## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/node-collector:0`
- Mirrored image: `<your-namespace>/dhi-node-collector:0`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Run the node-collector image

node-collector is a CLI tool from Aqua Security's
[k8s-node-collector](https://github.com/aquasecurity/k8s-node-collector) project. It gathers file system and process
information from Kubernetes cluster nodes for CIS benchmark compliance checking.

### View available commands

```bash
$ docker run --rm dhi.io/node-collector:0 --help
```

### View k8s subcommand help

The `k8s` subcommand is the main data collector that extracts node information from a Kubernetes cluster:

```bash
$ docker run --rm dhi.io/node-collector:0 k8s --help
```

In production, node-collector is typically deployed as a short-lived Kubernetes Job that runs on each node to collect
compliance data. Refer to the [upstream documentation](https://github.com/aquasecurity/k8s-node-collector) for
Kubernetes deployment examples.

## Deploying to Kubernetes

node-collector is designed to run as a short-lived Kubernetes Job against each cluster node, not as a long-running
service. It inspects node-level files (`/var/lib/kubelet`, `/etc/kubernetes`, `/var/lib/etcd`, `/etc/systemd`) by
shelling out to utilities like `stat`, `ps`, and `awk`, and returns a JSON report used for CIS Kubernetes Benchmark
compliance checks.

### Canonical deployment path

Most users run node-collector indirectly via [Trivy Operator](https://github.com/aquasecurity/trivy-operator), which
launches node-collector Jobs against each node automatically with the correct Pod spec (user, volume mounts, and encoded
configuration). No manual Job authoring is required in that flow.

### Standalone deployment

If you deploy node-collector directly (without Trivy Operator), your Pod spec must meet the same requirements as
[upstream's reference Job](https://github.com/aquasecurity/k8s-node-collector/blob/v0.3.1/tests/e2e/job.yaml):

- **Run as root** (`securityContext.runAsUser: 0`, `runAsGroup: 0`). The default DHI `nonroot` user cannot read the
  root-owned kubelet, etcd, and systemd config files the collector audits, so most CIS checks return empty results under
  nonroot. This is an upstream-level requirement — see upstream's Job manifest for the same setting.
- **Mount the node's configuration directories** via `hostPath` (`/var/lib/kubelet`, `/etc/kubernetes`, `/var/lib/etcd`,
  `/etc/systemd`, `/lib/systemd`, `/etc/cni/net.d`, `/var/lib/kube-scheduler`, `/var/lib/kube-controller-manager`).
- **Provide encoded configuration** via the `--node-config` and `--node-commands` flags (each a base64-encoded,
  bzip2-compressed YAML blob describing the files to inspect and the audit commands to run).
- **Enable `hostPID: true`** so the collector can inspect host processes through `/proc`.

Because of these requirements, standalone deployment is uncommon; the Trivy Operator path is recommended unless you have
a specific reason to run it directly.

### FIPS deployments

If you run the FIPS variant against an API server that negotiates post-quantum TLS (Go 1.24+ defaults to
`X25519MLKEM768` for TLS key exchange), the in-cluster handshake may fail under strict `fips140=only` because ML-KEM is
not yet covered by the validated FIPS 140 module. If you hit this, add `GODEBUG: fips140=only,tlsmlkem=0` to the Pod's
`env` to disable the ML-KEM offer and fall back to classical curves:

```yaml
env:
  - name: GODEBUG
    value: fips140=only,tlsmlkem=0
```

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
