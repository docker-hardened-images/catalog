## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image provides DRBD (Distributed Replicated Block Device) user-space utilities, including `drbdadm`, `drbdsetup`,
`drbdmeta`, `drbdmon`, and `drbd-events-log-supplier`. These utilities are used to configure, manage, and monitor DRBD
resources in a cluster.

**Note**: This image does not include a shell or default command. It is intended to be used as a base image or with
explicit commands. The utilities are located in `/usr/sbin/`.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

### Verify utilities are available

Use `drbdadm` to display version information and validate that the image is working:

```
$ docker run --rm dhi.io/drbd-utils:<tag> /usr/sbin/drbdadm --version
```

### Common usage patterns

**Display DRBD configuration:**

```
$ docker run --rm -v /path/to/drbd.conf:/etc/drbd.conf:ro dhi.io/drbd-utils:<tag> /usr/sbin/drbdadm dump all
```

**Setup a DRBD resource:**

```
$ docker run --rm --privileged -v /path/to/drbd.conf:/etc/drbd.conf:ro dhi.io/drbd-utils:<tag> /usr/sbin/drbdadm up <resource-name>
```

**Monitor DRBD status:**

```
$ docker run --rm dhi.io/drbd-utils:<tag> /usr/sbin/drbdmon
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
| Entry point        | This image has no default entrypoint or CMD. You must specify the full path to the utility you want to run (e.g., `/usr/sbin/drbdadm`).                                     |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |

## Configuration

DRBD utilities read configuration from `/etc/drbd.conf` and `/etc/drbd.d/*.conf`. The default configuration file
`/etc/drbd.d/global_common.conf` is included in the image. Mount your custom configuration files as volumes:

```
$ docker run --rm -v /path/to/drbd.conf:/etc/drbd.conf:ro -v /path/to/drbd.d:/etc/drbd.d:ro dhi.io/drbd-utils:<tag> /usr/sbin/drbdadm dump all
```

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

This image has no default entrypoint or CMD. You must always specify the full path to the utility you want to run:

- `/usr/sbin/drbdadm` - Main DRBD administration tool
- `/usr/sbin/drbdsetup` - Low-level DRBD setup tool
- `/usr/sbin/drbdmeta` - DRBD metadata manipulation tool
- `/usr/sbin/drbdmon` - DRBD monitoring tool
- `/usr/sbin/drbd-events-log-supplier` - Event logging utility

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
