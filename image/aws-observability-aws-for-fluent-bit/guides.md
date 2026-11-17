## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/aws-observability-aws-for-fluent-bit:<tag>`
- Mirrored image: `<your-namespace>/dhi-aws-observability-aws-for-fluent-bit:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

AWS for Fluent Bit forwards logs with the Kinesis Streams, Data Firehose, and CloudWatch Logs plugins. This image
replaces `public.ecr.aws/aws-observability/aws-for-fluent-bit`. Plugin configuration and the upstream examples are at
https://github.com/aws/aws-for-fluent-bit.

## Start an AWS for Fluent Bit image

The image has no OCI entrypoint. The default command is `/entrypoint.sh`. That script prints the image version, loads
the CloudWatch, Kinesis, and Firehose plugins, and starts Fluent Bit with `/fluent-bit/etc/fluent-bit.conf`. It ignores
extra arguments.

The default config listens on `0.0.0.0:24224` and sends matching records to CloudWatch Logs (`log_group_name`
`fluent-bit-cloudwatch`, region `us-east-1`). The process keeps running until you stop it. Idle startup does not call
AWS. After a record is flushed, the CloudWatch plugin contacts AWS. Without credentials it logs `NoCredentialProviders`
and retries. That is the upstream default config.

```bash
$ docker run --rm -p 24224:24224 \
  dhi.io/aws-observability-aws-for-fluent-bit:<tag>
```

The first line is `AWS for Fluent Bit Container Image Version 3.5.5` on the 3.5.5 image. The banner then reports
`Fluent Bit v5.1.2`, and Fluent Bit logs `listening on 0.0.0.0:24224`.

### Print the Fluent Bit version

`docker run IMAGE --version` replaces `/entrypoint.sh` with `--version` and fails. Run the binary directly. The same
binary is at the legacy path `/fluent-bit/bin/fluent-bit`.

```bash
$ docker run --rm --entrypoint /usr/bin/fluent-bit \
  dhi.io/aws-observability-aws-for-fluent-bit:<tag> --version
```

```bash
$ docker run --rm --entrypoint /fluent-bit/bin/fluent-bit \
  dhi.io/aws-observability-aws-for-fluent-bit:<tag> --version
```

Both print `Fluent Bit v5.1.2`.

## Run with a custom configuration

Mount your file over `/fluent-bit/etc/fluent-bit.conf`. Passing `-c` on the `docker run` command line does not change
the config, because `/entrypoint.sh` ignores extra arguments and always opens that path.

Create `fluent-bit.conf` in the current directory. This accepts Fluent forward records on port 24224 and writes them to
stdout:

```conf
[SERVICE]
    Flush        1
    Log_Level    info

[INPUT]
    Name         forward
    Listen       0.0.0.0
    Port         24224

[OUTPUT]
    Name         stdout
    Match        *
```

Create `send.conf` beside it. This emits one record and forwards it to the first container:

```conf
[SERVICE]
    Flush        1
    Log_Level    info

[INPUT]
    Name         dummy
    Tag          demo
    Dummy        {"message":"hello from aws for fluent bit"}
    Samples      1

[OUTPUT]
    Name         forward
    Match        *
    Host         aws-for-fluent-bit
    Port         24224
```

The mounted files must be readable by uid 65532. Start the server first and give it a moment to listen, then start the
sender. Both stay running. `docker logs` on the server shows the record.

```bash
$ chmod 644 fluent-bit.conf send.conf
$ docker network create aws-for-fluent-bit
$ docker run -d --name aws-for-fluent-bit --network aws-for-fluent-bit \
  -v "$(pwd)/fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro" \
  dhi.io/aws-observability-aws-for-fluent-bit:<tag>
$ sleep 2
$ docker run -d --name aws-for-fluent-bit-send --network aws-for-fluent-bit \
  -v "$(pwd)/send.conf:/fluent-bit/etc/fluent-bit.conf:ro" \
  dhi.io/aws-observability-aws-for-fluent-bit:<tag>
$ sleep 5
$ docker logs aws-for-fluent-bit
```

The server log includes `listening on 0.0.0.0:24224` and a stdout record:

```text
[0] demo: [[1793372098.286012890, {}], {"message"=>"hello from aws for fluent bit"}]
```

The timestamp in that line changes from run to run. Stop the containers when you are done:

```bash
$ docker rm -f aws-for-fluent-bit aws-for-fluent-bit-send
$ docker network rm aws-for-fluent-bit
```

## Non-hardened images vs. Docker Hardened Images

Differences from `public.ecr.aws/aws-observability/aws-for-fluent-bit` that change how you run this image:

- The container user is uid 65532. The upstream image runs as root.
- Publish `24224`. The upstream image metadata exposes `2020/tcp`. The shipped config listens on `24224` and does not
  listen on `2020`.
- `/fluent-bit`, `/entrypoint.sh`, `/ecs`, and `/AWS_FOR_FLUENT_BIT_VERSION` are still present.
- Arrow and Parquet outputs are not compiled in. The upstream Amazon Linux 2023 image includes `libarrow` and
  `libparquet`.
- This image does not include the Amazon Linux userspace.
- There is no Alpine variant. musl cannot `dlopen` the Go output plugins, so an Alpine image is not published.

### Troubleshooting

`/entrypoint.sh` is a bash script, so the runtime image includes `/bin/bash`. It does not include a package manager. The
generic "no shell" notes further down in this guide describe other Docker Hardened Images. For a root shell and a
package manager, use a dev tag, which is the runtime tag with `-dev` appended (for example `3.5.5-debian13-dev`):

```bash
$ docker run --rm --entrypoint id \
  dhi.io/aws-observability-aws-for-fluent-bit:<tag>-dev
```

The command prints `uid=0(root)`.

Files mounted into the runtime image must be readable by uid 65532. `/fluent-bit/log` is writable by that user (mode
`0770`). A config file with mode `600` owned by another user fails with `could not open configuration file`.

There is no OCI entrypoint. Extra arguments replace `/entrypoint.sh`, so appending `--version` or `-c` does not reach
Fluent Bit. Use `--entrypoint /usr/bin/fluent-bit` to run the binary, and mount a custom config over
`/fluent-bit/etc/fluent-bit.conf`.

FIPS variants exist for this image. Their tags include `fips`. The commands above use the non-FIPS image.

## Run as an Amazon ECS FireLens log router

The image runs as uid 65532. The upstream image runs as root. FireLens gives the log router a Unix socket at
`/var/run/fluent.sock` that the application containers write to. Amazon ECS sets the owner of that socket directory to
the log router's uid only when the task definition sets the user, so without it the directory stays root-owned and the
log router cannot bind the socket.

Set `user` to `65532` on the log router container definition:

```json
{
  "containerDefinitions": [
    {
      "name": "log_router",
      "image": "dhi.io/aws-observability-aws-for-fluent-bit:<tag>",
      "essential": true,
      "user": "65532",
      "firelensConfiguration": {
        "type": "fluentbit"
      }
    }
  ]
}
```

Running a non-root FireLens container needs Amazon ECS container agent 1.96.0 or later and an Amazon ECS-optimized AMI
version v20250716 or later. The uid must not be used by any other container in the task or on the container instance.

Without the `user` setting, Fluent Bit logs `Cannot bind to or listen on /var/run/fluent.sock`, and records sent by
application containers with the `awsfirelens` log driver never arrive. See the
[AWS FireLens documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_firelens.html) for the
rest of the FireLens setup.

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
