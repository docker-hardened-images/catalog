## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this opentelemetry-autoinstrumentation-nodejs image

This Docker Hardened opentelemetry-autoinstrumentation-nodejs image includes:

- The OpenTelemetry Node.js auto-instrumentation bundle that the OpenTelemetry Operator ships as its Node.js init image.
  It is `@opentelemetry/auto-instrumentations-node` with its production dependencies, built from the operator's
  `autoinstrumentation/nodejs` recipe.
- The bundle at `/usr/lib/opentelemetry-autoinstrumentation-nodejs`, with `/autoinstrumentation` linked to it. The link
  is the path the OpenTelemetry Operator copies from.
- `cp`, which the operator needs to copy the bundle out of this image and into the instrumented workload.

This image is a carrier for the bundle. It does not contain a Node.js runtime. The bundle is loaded by your
application's own Node.js process, not by this container.

## Run the container

The image has no entry point. Its default command is the same copy the OpenTelemetry Operator injects, so a manual run
only needs a volume mounted at `/otel-auto-instrumentation-nodejs`:

```bash
docker run --rm -v otel-nodejs-agent:/otel-auto-instrumentation-nodejs dhi.io/opentelemetry-autoinstrumentation-nodejs:<tag>
```

To copy the bundle onto the host instead, override the command and mount a host directory that UID 65532 can write to:

```bash
mkdir -p otel-nodejs && chmod 0777 otel-nodejs
docker run --rm -v "$(pwd)/otel-nodejs:/out" dhi.io/opentelemetry-autoinstrumentation-nodejs:<tag> cp -r /autoinstrumentation/. /out
```

The trailing `/.` in the source path matters. `/autoinstrumentation` is a symbolic link, and `cp` copies only the link
unless the path ends in `/.`. For example, `cp -r /autoinstrumentation /out` leaves only an `autoinstrumentation` link
in `/out`. `docker cp` also copies only the link, unless you add `-L` to follow it. To copy from a stopped container
onto the host, use a destination that does not exist yet:

```bash
cid=$(docker create dhi.io/opentelemetry-autoinstrumentation-nodejs:<tag>)
docker cp -L "$cid:/autoinstrumentation" ./otel-nodejs-copy
docker rm "$cid"
```

To load the bundle into a Node.js application, point `NODE_OPTIONS` at the copied entry point. The volume directory is
owned by UID and GID 65532 with mode `0770`, so an application that runs as another UID must join group 65532 to read
it. The example uses a small `app.js` that makes one request to its own server and then exits. Create it in the current
directory:

```bash
cat > app.js <<'EOF'
const http = require('http');
const server = http.createServer((req, res) => res.end('ok')).listen(8080, () => {
  http.get('http://127.0.0.1:8080/', (res) => {
    res.resume();
    res.on('end', () => server.close());
  });
});
EOF
```

Then run it. The `otel-nodejs-agent` volume must already hold the bundle from the first example:

```bash
docker run --rm --group-add 65532 \
  -e NODE_OPTIONS="--require /otel-auto-instrumentation-nodejs/autoinstrumentation.js" \
  -v otel-nodejs-agent:/otel-auto-instrumentation-nodejs:ro \
  -e OTEL_SERVICE_NAME=my-service -e OTEL_TRACES_EXPORTER=console \
  -v "$(pwd)/app.js:/app/app.js:ro" dhi.io/node:22-debian13 node /app/app.js
```

The Operator does not need this. Its shared volume is an `emptyDir`, which is root-owned with mode `0777`.

## Use with the OpenTelemetry Operator

Point the `nodejs` image of an `Instrumentation` resource at this image. The operator injects it as an init container
that copies the bundle into a shared volume, then sets `NODE_OPTIONS` on your application container:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: nodejs-instrumentation
spec:
  exporter:
    endpoint: http://otel-collector:4318
  nodejs:
    image: dhi.io/opentelemetry-autoinstrumentation-nodejs:<tag>
```

Annotate the workload you want instrumented:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-nodejs: "true"
```

The operator sets `NODE_OPTIONS` to require `/otel-auto-instrumentation-nodejs/autoinstrumentation.js` and sets
`OTEL_METRICS_EXPORTER=otlp` when you have not set it.

### Running the init container as nonroot

This image runs as UID 65532. Upstream runs as root, so some clusters that worked with the upstream image need one of
these settings:

- A `PersistentVolumeClaim` target that is root-owned with mode `0755` needs `fsGroup` on the pod, or the copy fails
  with `cp: cannot create directory ... Permission denied`.
- An app container with `runAsNonRoot: true` and no `runAsUser` now starts. Upstream was rejected at that point.
- Set `spec.initContainerSecurityContext` if the init container must run as a different user from the app.

Operator versions up to v0.96.0 are not supported with this image. Those versions use `cp -a`, which exits 1 on the
volume root.

## Configure the application

The bundle is configured through environment variables on the *instrumented application* container, not on this image.
The most commonly used ones are below; see the
[Node.js SDK configuration docs](https://opentelemetry.io/docs/languages/js/configuration/) for the full set.

| Variable                       | Description                                   | Default                 |
| ------------------------------ | --------------------------------------------- | ----------------------- |
| `OTEL_SERVICE_NAME`            | Logical name of the instrumented service      | `unknown_service`       |
| `OTEL_EXPORTER_OTLP_ENDPOINT`  | Endpoint the OTLP exporter sends telemetry to | `http://localhost:4318` |
| `OTEL_TRACES_EXPORTER`         | Trace exporter to use                         | `otlp`                  |
| `OTEL_NODE_RESOURCE_DETECTORS` | Resource detectors to run at startup          | `all`                   |

`OTEL_NODE_RESOURCE_DETECTORS=all` probes cloud metadata endpoints at startup. In a cluster outside those clouds, set it
to `env,host,os,process` so startup does not stall on unreachable endpoints.

## FIPS variants

The `fips` tags carry OS-level FIPS posture and the STIG scan. This image performs no cryptography itself: the bundle is
JavaScript that the operator copies into your workload, and its crypto runs in that application's Node.js process
through OpenSSL. The bundle is identical in FIPS and non-FIPS tags. To cover the instrumentation's own operations, run
the instrumented application on a FIPS Node.js image, such as `dhi.io/node:22-debian13-fips`.

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
