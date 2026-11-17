## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## About this image

SendGrid Python is a **library**, not a service. This image ships the SendGrid SDK preinstalled into a hardened Python
3.14 runtime, with the venv interpreter as the entry point, so running the image drops you into a Python that can
already `import sendgrid`. There is no server to start and no port to expose.

## Verify the SDK is available

```bash
$ docker run --rm dhi.io/sendgrid-python:<tag> -c "import sendgrid; print(sendgrid.__version__)"
```

## Run a SendGrid script

The entry point is `python3`, so you can mount a script and run it directly. SendGrid reads the API key from the
`SENDGRID_API_KEY` environment variable.

```bash
$ docker run --rm \
    -e SENDGRID_API_KEY \
    -v "$PWD/send.py:/app/send.py:ro" \
    dhi.io/sendgrid-python:<tag> /app/send.py
```

A minimal `send.py`:

```python
import os
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

message = Mail(
    from_email="from@example.com",
    to_emails="to@example.com",
    subject="Sending with SendGrid is Fun",
    plain_text_content="and easy to do anywhere, even with Python",
)

client = SendGridAPIClient(os.environ["SENDGRID_API_KEY"])
response = client.send(message)
print(response.status_code)
```

## Use as a base image

Because the SDK is already present in the default Python environment, you can build your own application on top of this
image without a separate `pip install` step for sendgrid. Use the `dev` variant when you need a shell or package manager
during the build stage, and the non-dev variant for your runtime stage.

The entry point on every variant is `python3`, so a bare `docker run <img>:<tag>-dev` starts the interpreter rather than
a shell. In a Dockerfile, `RUN` ignores the entry point, so build stages work normally; for an interactive shell,
override the entry point explicitly:

```bash
$ docker run --rm -it --entrypoint bash dhi.io/sendgrid-python:<tag>-dev
```

```dockerfile
FROM dhi.io/sendgrid-python:<tag>
WORKDIR /app
COPY app.py .
CMD ["/app/app.py"]
```

### Installing your own dependencies alongside the SDK

The SDK lives in a virtual environment at `/usr/lib/sendgrid-python`, and to keep the runtime minimal that venv ships
without `pip`. To add your own packages into the same environment, bootstrap `pip` with `ensurepip` in a `dev` build
stage, install what you need, then copy the finished venv into a non-dev runtime stage:

```dockerfile
FROM dhi.io/sendgrid-python:<tag>-dev AS build
RUN python3 -m ensurepip && \
    python3 -m pip install --no-cache-dir requests==2.32.3

FROM dhi.io/sendgrid-python:<tag>
COPY --from=build /usr/lib/sendgrid-python /usr/lib/sendgrid-python
WORKDIR /app
COPY app.py .
CMD ["/app/app.py"]
```

Pin the versions you add so they remain reproducible and can be bumped deliberately when a CVE fix is needed.

## FIPS variants

FIPS variants (tags containing `fips`, on the debian-13 line) ship the CMVP-validated OpenSSL FIPS provider and enforce
it system-wide via `OPENSSL_CONF` / `OPENSSL_MODULES`. Python 3.14 links the system OpenSSL, so the SDK's TLS traffic,
including `python_http_client`'s HTTPS calls to the SendGrid API, goes through the FIPS module. The `cryptography`
extension in the venv is built against the same system OpenSSL rather than shipping its own, so the SDK's `EventWebhook`
ECDSA signature helper runs under the FIPS provider as well.

```bash
$ docker run --rm dhi.io/sendgrid-python:<tag>-fips -c "import ssl; from cryptography.hazmat.backends.openssl.backend import backend; print(ssl.OPENSSL_VERSION); print(backend.openssl_version_text())"
```

Both lines print the same OpenSSL version. Non-approved algorithms are rejected in both stacks; for example,
`hashlib.md5()` and `cryptography`'s `MD5` hash fail in FIPS variants.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations.

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
