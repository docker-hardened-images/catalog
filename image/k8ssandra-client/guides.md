## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi/k8ssandra-client:<tag>`
- Mirrored image: `<your-namespace>/dhi-k8ssandra-client:<tag>`

### What's included in this k8ssandra-client image

This Docker Hardened k8ssandra-client image includes:

- **kubectl-k8ssandra**: The main kubectl plugin for managing K8ssandra clusters
- **kubectl**: Kubernetes command-line tool for general Kubernetes operations
- **yq**: YAML processor for inspecting and transforming YAML documents

## Start a k8ssandra-client image

The k8ssandra-client image is a kubectl plugin designed to manage K8ssandra clusters running on Kubernetes. It requires
access to a Kubernetes cluster via kubeconfig.

### Basic usage

Display help information:

```bash
$ docker run --rm dhi/k8ssandra-client:<tag>
```

Run a k8ssandra command with kubeconfig mounted:

```bash
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi/k8ssandra-client:<tag> \
  [command] [flags]
```

### Using kubectl from the image

The image also includes kubectl for general Kubernetes operations:

```bash
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  --entrypoint kubectl \
  dhi/k8ssandra-client:<tag> \
  get pods -n k8ssandra-operator
```

### Environment variables

The k8ssandra-client image does not require environment variables for basic operation. Configuration is handled through
kubeconfig and command-line flags.

Standard kubectl flags are available:

| Flag                  | Description                   | Example                            |
| --------------------- | ----------------------------- | ---------------------------------- |
| `--kubeconfig`        | Path to kubeconfig file       | `--kubeconfig /path/to/config`     |
| `--context`           | Kubernetes context to use     | `--context my-cluster`             |
| `--namespace` or `-n` | Kubernetes namespace          | `-n k8ssandra-operator`            |
| `--server`            | Kubernetes API server address | `--server https://k8s.example.com` |

## Common k8ssandra-client use cases

### View available commands

List the available top-level commands:

```bash
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi/k8ssandra-client:<tag> \
  --help
```

### Run nodetool commands on Cassandra pods

The `nodetool` subcommand runs Cassandra maintenance commands against a selected pod:

```bash
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi/k8ssandra-client:<tag> \
  nodetool my-cassandra-pod-0 status -n k8ssandra-operator
```

Review the available options for the subcommand:

```bash
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi/k8ssandra-client:<tag> \
  nodetool --help
```

### Manage Cassandra cluster lifecycle

The image includes lifecycle commands for starting, stopping, and restarting managed Cassandra resources.

Review the command help before running these operations in your environment:

```bash
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi/k8ssandra-client:<tag> \
  stop --help
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi/k8ssandra-client:<tag> \
  start --help
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi/k8ssandra-client:<tag> \
  restart --help
```

### Estimate datacenter expansion capacity

The `tools` command group includes utility operations such as expansion estimates:

```bash
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi/k8ssandra-client:<tag> \
  tools --help
```

### Additional command groups

The image also includes `config`, `helm`, `register`, and `users` command groups. These workflows tend to be highly
environment-specific, so use the built-in help as your starting point and defer to upstream K8ssandra documentation for
topology-specific procedures:

```bash
$ docker run --rm dhi/k8ssandra-client:<tag> config --help
$ docker run --rm dhi/k8ssandra-client:<tag> helm --help
$ docker run --rm dhi/k8ssandra-client:<tag> register --help
$ docker run --rm dhi/k8ssandra-client:<tag> users --help
```

### Use in Kubernetes Jobs

You can run `k8ssandra-client` inside Kubernetes `Job` or `CronJob` resources when you want to automate routine
operations.

The exact manifest, service account, RBAC, and command arguments depend on your cluster layout and the K8ssandra
resources you manage, so prefer using your existing Kubernetes automation patterns rather than copying a fixed manifest.

Before creating an automated workflow, review the available commands with:

```bash
$ docker run --rm dhi/k8ssandra-client:<tag> --help
$ docker run --rm dhi/k8ssandra-client:<tag> <command> --help
```

If you run the image inside a cluster, ensure the workload has the kubeconfig, context, and RBAC permissions required
for the resources it needs to access.

### Use with specific Kubernetes context

When working with multiple clusters, you can select a kubeconfig context with the global `--context` flag:

```bash
$ docker run --rm \
  -v ~/.kube/config:/home/nonroot/.kube/config:ro \
  dhi/k8ssandra-client:<tag> \
  --context <context-name> \
  nodetool <pod-name> status -n <namespace>
```

### Register a data plane

The `register` workflow is environment-specific and requires source and destination cluster details. Use the built-in
help to review the current flags before following upstream K8ssandra operational guidance for your topology:

```bash
$ docker run --rm dhi/k8ssandra-client:<tag> register --help
```

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened k8ssandra-client image has the following differences compared to the upstream image:

### Entrypoint path

- **Upstream**: `/kubectl-k8ssandra`
- **DHI**: `/usr/local/bin/kubectl-k8ssandra`

The CLI behavior is the same, but the explicit binary path is different. The DHI image follows standard Linux filesystem
conventions by placing binaries in `/usr/local/bin`, so update Dockerfiles or `--entrypoint` overrides that reference
the upstream path directly.

### Default command

- **Upstream**: No default CMD (requires command to be specified)
- **DHI**: Default CMD is `--help`

The DHI image provides a more user-friendly default behavior by displaying help information when run without arguments.

### TLS certificates

The DHI image includes the `SSL_CERT_FILE` environment variable pointing to `/etc/ssl/certs/ca-certificates.crt`,
ensuring TLS certificate validation works correctly out of the box.

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
