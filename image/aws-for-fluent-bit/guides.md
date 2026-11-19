## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-for-fluent-bit:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-for-fluent-bit:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this AWS for Fluent Bit image

This Docker Hardened AWS for Fluent Bit image includes:

- `fluent-bit`: the Fluent Bit log processor and forwarder
- `cloudwatch`, `kinesis` and `firehose`: the Amazon CloudWatch Logs, Amazon Kinesis Data Streams and Amazon Kinesis
  Data Firehose output plugins, loaded at start-up from `/fluent-bit/cloudwatch.so`, `/fluent-bit/kinesis.so` and
  `/fluent-bit/firehose.so`
- the configuration examples of the upstream project under `/ecs` and `/fluent-bit/configs`

For configuration reference, see the [AWS for Fluent Bit documentation](https://github.com/aws/aws-for-fluent-bit) and
the [Fluent Bit documentation](https://docs.fluentbit.io).

## Start an AWS for Fluent Bit image

### Basic usage

The default configuration accepts records on the forward protocol (port 24224) and writes them to Amazon CloudWatch
Logs. Give the container AWS credentials through the usual environment variables or an IAM role:

```bash
$ docker run -d --name aws-for-fluent-bit -p 24224:24224 \
  -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
  dhi.io/aws-for-fluent-bit:<tag>
```

### With a custom configuration

Mount your own configuration over `/fluent-bit/etc/fluent-bit.conf`. This example reads from the forward protocol and
prints to the container output:

```bash
$ cat > fluent-bit.conf <<'EOF2'
[INPUT]
    Name   forward
    Listen 0.0.0.0
    Port   24224

[OUTPUT]
    Name   stdout
    Match  *
EOF2

$ docker run --rm -p 24224:24224 \
  -v "$PWD/fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro" \
  dhi.io/aws-for-fluent-bit:<tag>
```

## Non-hardened images vs. Docker Hardened Images

- The image starts `fluent-bit` directly. Upstream starts `/entrypoint.sh`, a shell script that prints the image version
  and then runs the same command, so the runtime image has no `/entrypoint.sh` and prints no version banner. The
  `fluent-bit` binary is now the entrypoint, so pass only its arguments to run something else. For example,
  `docker run dhi.io/aws-for-fluent-bit:<tag> -c /my.conf` replaces the default command line, which loads the three AWS
  plugins with `-e`, so repeat the `-e` flags you need.
- The image runs as the nonroot user `65532`, where upstream runs as root. As an Amazon ECS FireLens log router it can
  stay nonroot: set `"user": "65532"` on the log router container in the task definition (the formats are `uid`,
  `uid:gid` and `uid:group`), and the ECS agent gives that user the directory of the FireLens unix socket. This needs
  ECS agent 1.96.0 or later and an Amazon ECS-optimized AMI v20250716 or later, and the UID must not be used by other
  containers in the task or on the instance, as the
  [AWS FireLens documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_firelens.html)
  describes. On an older agent the directory stays root-owned and Fluent Bit cannot bind `/var/run/fluent.sock`; set
  `"user": "0"` there as a workaround. As a Kubernetes DaemonSet that tails `/var/log/containers`, set
  `securityContext.runAsUser: 0`, because pod log files are root-owned.
- Fluent Bit is built without Apache Arrow, so the S3 output cannot compress with Arrow or Parquet.
- Three of upstream's nine parser files are not included: `parsers_kafka.conf`, `parsers_mult.conf` and
  `parsers_multiline.conf`. The other six are in `/fluent-bit/etc` and `/fluent-bit/parsers`. A configuration whose
  `Parsers_File` names one of the three fails to start, so copy that file into the container, for example by mounting it
  from the [Fluent Bit repository](https://github.com/fluent/fluent-bit/tree/master/conf).
- The image exposes port `24224` (the forward input the default configuration listens on) in addition to the metrics
  port `2020` that upstream exposes.

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
