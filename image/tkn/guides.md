## How to use this image

The image ships the `tkn` binary as its entrypoint, so arguments are passed straight through.

```bash
# Print the client version
docker run --rm dhi.io/tkn:<version> version

# Show available commands
docker run --rm dhi.io/tkn:<version> --help
```

### Connecting to a cluster

`tkn` resolves cluster credentials the same way `kubectl` does. Mount a kubeconfig and point `KUBECONFIG` at it:

```bash
docker run --rm \
  -v "$HOME/.kube/config:/kubeconfig:ro" \
  -e KUBECONFIG=/kubeconfig \
  dhi.io/tkn:<version> pipeline list
```

When running as a step image inside a Tekton `Task`, the injected ServiceAccount token is used automatically and no
kubeconfig is required.

### Following pipeline logs

```bash
docker run --rm \
  -v "$HOME/.kube/config:/kubeconfig:ro" \
  -e KUBECONFIG=/kubeconfig \
  dhi.io/tkn:<version> pipelinerun logs -f <pipelinerun-name>
```

### Working with OCI bundles

`tkn bundle` packages Tekton resources into an OCI image and reads them back. It talks to a registry and needs no
cluster:

```bash
# Package a Task into a bundle
docker run --rm -v "$PWD:/work:ro" -w /work \
  dhi.io/tkn:<version> bundle push registry.example.com/tekton/my-task:v1 -f task.yaml

# List the resources inside a bundle
docker run --rm dhi.io/tkn:<version> bundle list registry.example.com/tekton/my-task:v1
```

Registry credentials are read from a Docker or Podman config file. Mount one and set `DOCKER_CONFIG` to its directory.

### Using it in a Tekton Task

The runtime variant has no shell, so a step invokes `tkn` through `args` rather than through a `script` block:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: list-pipelines
spec:
  steps:
    - name: tkn
      image: dhi.io/tkn:<version>
      args: ["pipeline", "list"]
```

Tasks written against the upstream `tkn` image often use a `script` block instead, which Tekton executes with `/bin/sh`.
Those steps fail on the runtime variant:

```
exec: "/bin/sh": stat /bin/sh: no such file or directory
```

There are two ways to migrate such a step:

- If it only invokes `tkn`, replace the `script` block with `args`, as above.
- If it needs shell logic such as conditionals, command substitution or `eval`, use `dhi.io/tkn:<version>-dev`, which
  includes a shell. It runs as root by default, and a `securityContext` that pins `runAsUser` still applies.

### Color and emoji output

`tkn` disables color and emojis automatically when output is piped or run non-interactively, such as from a Tekton
`Task`. To disable them explicitly, set `NO_COLOR` or pass `--no-color`:

```bash
docker run --rm -e NO_COLOR="" dhi.io/tkn:<version> taskrun describe <name>
```

## Best practices

- Pin to a full version tag in production rather than a floating major tag
- Mount kubeconfig read-only and prefer a ServiceAccount when running in-cluster
- Use the runtime variant for `Task` steps that invoke `tkn` directly, and `-dev` for steps that need a shell

## Common issues

- **`Couldn't get kubeConfiguration namespace`** — no kubeconfig was found. Mount one and set `KUBECONFIG`, or run with
  a ServiceAccount in-cluster.
- **`bundle push` fails to authenticate** — mount a registry config and set `DOCKER_CONFIG` to the directory containing
  `config.json`.
- **`stat /bin/sh: no such file or directory`** — the runtime variant has no shell. Convert the step to `args`, or use
  the `-dev` variant.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Available image tags for tkn:**

| Variant Type          | Tag Examples                                             | Description                          |
| --------------------- | -------------------------------------------------------- | ------------------------------------ |
| **Standard (Debian)** | `<version>`, `<major>`                                   | Runtime variants for production use  |
|                       | `<version>-debian13`, `<major>-debian13`                 | Explicit Debian base specification   |
| **Standard (Alpine)** | `<version>-alpine`, `<major>-alpine`                     | Runtime variants on an Alpine base   |
|                       | `<version>-alpine3.24`, `<major>-alpine3.24`             | Explicit Alpine base specification   |
| **Development**       | `<version>-dev`, `<version>-alpine-dev`                  | Build-time variants with a shell     |
| **FIPS (Debian)**     | `<version>-fips`, `<version>-fips-dev`                   | FIPS-validated cryptographic modules |
|                       | `<version>-debian13-fips`, `<version>-debian13-fips-dev` | FIPS with explicit Debian base       |
| **FIPS (Alpine)**     | `<version>-alpine-fips`, `<version>-alpine-fips-dev`     | FIPS on an Alpine base               |
|                       | `<version>-alpine3.24-fips`                              | FIPS with explicit Alpine base       |

**Tag selection guidance:**

- Use `dhi.io/tkn:<version>` for standard production deployments
- Use `dhi.io/tkn:<version>-fips` for FIPS-compliant environments
- Use major version tags (like `:<major>`) for automatic minor updates (not recommended for production)
- Use `-dev` variants only in the first stage of a multi-stage build or for interactive debugging

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
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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
