## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image runs `drbd-reactor`, a daemon that monitors DRBD resources and executes actions based on state changes. It is
typically used as a sidecar container in Kubernetes pods alongside DRBD-enabled applications.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

### Basic usage

Start the drbd-reactor daemon. The image includes a default configuration file at `/etc/drbd-reactor.toml`:

```
$ docker run --rm dhi.io/drbd-reactor:<tag>
```

To use a custom configuration file, mount it over the default:

```
$ docker run --rm -v /path/to/config.toml:/etc/drbd-reactor.toml:ro dhi.io/drbd-reactor:<tag>
```

**Note:** If you need to run drbd-reactor interactively with the `-it` flag (for example, for debugging), you must also
pass the `--allow-tty` flag:

```
$ docker run --rm -it dhi.io/drbd-reactor:<tag> --allow-tty
```

Without `--allow-tty`, drbd-reactor will refuse to start in a terminal to prevent accidental interactive use.

### Kubernetes sidecar usage

This image is typically used as a sidecar container in Kubernetes pods:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: drbd-app
spec:
  containers:
    - name: drbd-reactor
      image: dhi.io/drbd-reactor:<tag>
      volumeMounts:
        - name: config
          mountPath: /etc/drbd-reactor.toml
          subPath: drbd-reactor.toml
    - name: app
      image: your-app:latest
      # Your application container
  volumes:
    - name: config
      configMap:
        name: drbd-reactor-config
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

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
  cryptographic operations.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                              |
| :----------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                 |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                           |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                  |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                          |
| Entry point        | The image uses `/usr/local/bin/drbd-reactor` as the CMD. The daemon reads configuration from `/etc/drbd-reactor.toml` by default.                                           |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

The image uses `/usr/local/bin/drbd-reactor` as the CMD. The daemon will start automatically when the container runs.
Ensure your configuration file is mounted at `/etc/drbd-reactor.toml`.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
