## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a jaeger-es-index-cleaner instance

Replace `<tag>` with the image variant you want to run.

Print all available flags:

```bash
docker run --rm dhi.io/jaeger-es-index-cleaner:<tag> --help
```

The tool takes two positional arguments and exits when the deletion pass completes:

```text
jaeger-es-index-cleaner NUM_OF_DAYS http://HOSTNAME:PORT
```

`NUM_OF_DAYS` is the retention window. Indices older than that many days are deleted; newer ones are left alone. There
is no version subcommand.

## Common jaeger-es-index-cleaner use cases

### Delete indices older than a retention window

Delete every Jaeger index older than 14 days from an Elasticsearch cluster reachable at `http://elasticsearch:9200`:

```bash
docker run --rm \
  --network my-network \
  dhi.io/jaeger-es-index-cleaner:<tag> \
  14 http://elasticsearch:9200
```

Passing `0` deletes every Jaeger index, including today's. Use it deliberately.

### Match a non-default index prefix

If Jaeger was configured with an `index_prefix`, the cleaner must be told the same prefix or it will find nothing to
delete:

```bash
docker run --rm \
  --network my-network \
  dhi.io/jaeger-es-index-cleaner:<tag> \
  --index-prefix jaeger-main \
  14 http://elasticsearch:9200
```

### Authenticate to a secured cluster

For a cluster with authentication enabled, supply credentials rather than embedding them in the URL:

```bash
docker run --rm \
  --network my-network \
  dhi.io/jaeger-es-index-cleaner:<tag> \
  --es.username elastic \
  --es.password changeme \
  --es.tls.enabled \
  14 https://elasticsearch:9200
```

`--es.token-file` and `--es.api-key-file` are also available for token-based clusters. If the cluster certificate is
signed by a private CA, add `--es.tls.ca /path/to/ca.crt`. Run `--help` for the full flag list.

### Rollover and archive indices

When Jaeger is deployed with the rollover index strategy, or writes archive indices, tell the cleaner which set to act
on:

```bash
docker run --rm \
  --network my-network \
  dhi.io/jaeger-es-index-cleaner:<tag> \
  --rollover \
  14 http://elasticsearch:9200
```

Use `--archive` to clean archive indices instead. `--archive` only applies with rollover.

### Pass flags as environment variables

Every flag can also be set as an environment variable: upper-case the flag name and replace `.` and `-` with `_`. The
upstream documentation uses this form:

```bash
docker run --rm \
  --network my-network \
  -e ROLLOVER=true \
  dhi.io/jaeger-es-index-cleaner:<tag> \
  14 http://elasticsearch:9200
```

### Run it on a schedule

The cleaner is a run-to-completion job, so schedule it rather than leaving it running. As a Kubernetes CronJob:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: jaeger-es-index-cleaner
spec:
  schedule: "0 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: jaeger-es-index-cleaner
              image: dhi.io/jaeger-es-index-cleaner:<tag>
              args:
                - "14"
                - "http://elasticsearch:9200"
```

Replace `<tag>` with the desired version.

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
