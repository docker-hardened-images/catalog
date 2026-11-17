## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Kyverno Policy Reporter UI instance

The UI shows the reports that a Policy Reporter API serves, so you normally deploy it with the Policy Reporter Helm
chart, as the next section shows. To check that the image starts on its own, run the `run` subcommand and replace
`<tag>` with the image variant you want to run.

```bash
docker run -d --name kyverno-policy-reporter-ui -p 127.0.0.1:8080:8080 \
  dhi.io/kyverno-policy-reporter-ui:<tag> run
curl http://127.0.0.1:8080/healthz
```

The health endpoint answers `null` with status 200. The port binds to localhost only, because the UI has no login unless
you configure OpenID Connect or OAuth. Without a configuration file the UI logs `failed to load config file` and starts
with no cluster, so it shows no reports.

## Common Kyverno Policy Reporter UI use cases

### Deploy the UI with the Policy Reporter Helm chart

Install the upstream Policy Reporter chart and point both Policy Reporter and its UI at Docker Hardened Images. Replace
`<your-registry-secret>` with your [Kubernetes image pull secret](https://docs.docker.com/dhi/how-to/k8s/), `<core-tag>`
with a `dhi.io/kyverno-policy-reporter` tag, and `<tag>` with a `dhi.io/kyverno-policy-reporter-ui` tag.

```bash
helm repo add policy-reporter https://kyverno.github.io/policy-reporter
helm repo update

helm upgrade --install policy-reporter policy-reporter/policy-reporter \
  --create-namespace -n policy-reporter \
  --set "imagePullSecrets[0].name=<your-registry-secret>" \
  --set image.registry=dhi.io \
  --set image.repository=kyverno-policy-reporter \
  --set image.tag=<core-tag> \
  --set ui.enabled=true \
  --set "ui.imagePullSecrets[0].name=<your-registry-secret>" \
  --set ui.image.registry=dhi.io \
  --set ui.image.repository=kyverno-policy-reporter-ui \
  --set ui.image.tag=<tag>
```

The chart runs the UI as user 1234 with a read-only root filesystem and mounts its configuration at `/app/config.yaml`.
The image works with those settings as they are.

### Open the UI

Forward the UI service port and open <http://localhost:8080> in a browser.

```bash
kubectl port-forward -n policy-reporter service/policy-reporter-ui 8080:8080
```

## Non-hardened images vs. Docker Hardened Images

- The upstream image's entrypoint is `/ko-app/policy-reporter-ui`. This image's entrypoint is
  `/usr/local/bin/kyverno-policy-reporter-ui`, a symlink to `/usr/bin/kyverno-policy-reporter-ui`. The upstream path
  `/ko-app/policy-reporter-ui` is a symlink to the same binary, so pass only arguments, starting with `run`.
- The upstream image reads the UI and the report templates from `KO_DATA_PATH=/var/run/ko`. This image sets
  `KO_DATA_PATH=/kodata`, a symlink to `/usr/share/kyverno-policy-reporter-ui`, where the package installs them.
- This image exposes port 8080/tcp, the UI's default port. The upstream image declares no port.
- In FIPS variants the UI only completes a TLS handshake with a Policy Reporter API that offers a FIPS-approved key
  exchange. Against an API that offers only X25519 the handshake fails, and the report pages return an error.

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
