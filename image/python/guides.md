> [!NOTE]
>
> The installation location of python has changed from `/opt` to `/usr` to align with
> [FHS](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html).
>
> If you have a hardcoded dependency on the existing python path, you'll need to update those references. Otherwise,
> this change shouldn't impact you.
>
> Optionally, you can temporarily pin to the last digest to use the `/opt` path while you migrate any dependencies on
> the old path. The last digests on the old path are listed at the [end of this guide](#image-digests-for-the-opt-path).

## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Build and run a Python application

The recommended way to use this image is to use a multi-stage Dockerfile with the `-dev` version of the image as the
build stage. For the runtime stage, simply remove the `-dev` suffix from the image tag. For example, use the image tag
`dhi.io/python:3.9.23-debian13-fips-dev` for the build stage, and use `dhi.io/python:3.9.23-debian13-fips` for the
runtime stage.

Create a new directory and use the following Dockerfile to get started. Replace `<tag>` with the image variant.

```Dockerfile
# syntax=docker/dockerfile:1

## -----------------------------------------------------
## Build stage (use tag with -dev suffix: e.g. 3.9.23-debian13-fips-dev)
FROM dhi.io/python:<tag> AS build-stage

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/app/venv/bin:$PATH"

WORKDIR /app

RUN python -m venv /app/venv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

## -----------------------------------------------------
## Final stage (use the same tag as above but without the -dev suffix e.g. 3.9.23-debian13-fips)
FROM dhi.io/python:<tag> AS runtime-stage

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/app/venv/bin:$PATH"

WORKDIR /app

COPY --from=build-stage /app/venv /app/venv
COPY app.py .

CMD ["python", "/app/app.py"]
```

Next, create `app.py` and `requirements.txt` files in the same directory.

```python
# app.py

import openai
import numpy as np
import pandas as pd

def main():
    print("Package versions:")
    print(f"openai: {openai.__version__}")
    print(f"numpy: {np.__version__}")
    print(f"pandas: {pd.__version__}")

if __name__ == "__main__":
    main()
```

```
openai
numpy
pandas
```

Run the following commands to build and run the sample app. You should see output printing the package versions.

```
docker build -t my-python-app .
docker run --rm --name my-running-app my-python-app
```

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

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. Docker Hardened Python images include FIPS-compliant variants for environments requiring
Federal Information Processing Standards compliance.

Modify your `app.py` file to the following script to verify FIPS status and availability.

```python
# app.py

import ssl
import hashlib

def main():
    try:
        hashlib.md5("test_str".encode("utf-8")).hexdigest()
        print("MD5: Available (not FIPS safe)")
    except ValueError as e:
        print("MD5: Disabled (FIPS safe)")

    # list available ciphers
    try:
        ctx = ssl.create_default_context()
        ciphers = [c['name'] for c in ctx.get_ciphers()]
        print("Cipher count:", len(ciphers))
    except Exception as e:
        print("Error getting ciphers:", e)

if __name__ == "__main__":
    main()
```

Rebuild your image and then run `docker run --rm --name my-running-app my-python-app` again to print FIPS status and
available modules. You should see the following output if FIPS is enabled:

```
MD5: Disabled (FIPS safe)
Cipher count: 26
```

#### Recompiling Python dependencies with the FIPS OpenSSL provider

When importing Python packages that have binaries pre-built, those binaries might bundle or link to a non-FIPS OpenSSL
implementation. For packages such as `cryptography`, build them from source and disable vendored OpenSSL so they link
against the FIPS OpenSSL in the image. The FIPS dev image already includes `libssl-dev` and `libzstd-dev`, so install
only the remaining build tools before running `pip`.

```Dockerfile
# syntax=docker/dockerfile:1
FROM dhi.io/python:<tag>-fips-dev AS build-stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/.venv/bin:$PATH"

RUN python -m venv /.venv
# Rebuild cryptography against the image's OpenSSL instead of the vendored wheel.
RUN apt-get update && apt-get install -y --no-install-recommends \
    cargo \
    gcc \
    libffi-dev \
    pkg-config \
    rustc \
    && rm -rf /var/lib/apt/lists/*
RUN OPENSSL_NO_VENDOR=1 OPENSSL_STATIC=0 \
    pip install --no-cache-dir --no-binary cryptography cryptography

FROM dhi.io/python:<tag>-fips AS build-stage
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/.venv/bin:$PATH"
WORKDIR /
COPY --from=build-stage /.venv /.venv
CMD ["python"]
```

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

## Image digests for the `/opt` path

The installation location of Python has moved from `/opt` to `/usr`. If you need to temporarily keep the old `/opt` path
while you migrate, pin to one of the digests below. These are the last images published with Python installed under
`/opt`.

| Tag                | Digest                                                                    |
| :----------------- | :------------------------------------------------------------------------ |
| `3.10`             | `sha256:08b6de53766579c663677b20d180bcf0c0df4f8038a4af75f4425cf277dcf546` |
| `3.10-dev`         | `sha256:b8f4cb5db6c26bd699dd27f3a86b14b8adf4acbe2ef5212e8278d71f8fbbdf50` |
| `3.10-fips`        | `sha256:582387b6670da6ff1cfd55958b5b2440ca08b6a340a188282fc615d672dc5313` |
| `3.10-fips-dev`    | `sha256:53b81230633a5740b25c41130445227732ab4d76158892849187bbd3ee043ca6` |
| `3.10-sfw-dev`     | `sha256:e2438807d8a718d644c6a3fdcca417ff11e4ef673bbd145f7265f51e8521fb34` |
| `3.10-sfw-ent-dev` | `sha256:997107b4c62057ebb550daeffdf55bae42b376aee5acab23fa91bdb7d18a9d2f` |
| `3.11`             | `sha256:dfe518d9ac0c0188f7bbac4f098d5afc5a2449e545e710d53ded4564dcbf70f7` |
| `3.11-dev`         | `sha256:92c4e9e14ead7546a8a2b91129ad4c5053628fbaf1326eed6c9d54944dc03290` |
| `3.11-fips`        | `sha256:9f343011e2021f913f7d099378d9e2da9322ff285996b3c2fc4b0c7a22d3b384` |
| `3.11-fips-dev`    | `sha256:3abf32e2634f51946735d9ef3600d3a951ac124c158b998b59c5450673e1fbdb` |
| `3.11-sfw-dev`     | `sha256:c39b01a0e3e0d127a0f01ae0d12b481418d9154bc3e78658958a40685da4103b` |
| `3.11-sfw-ent-dev` | `sha256:b21a47fd2ca663c3f3114f7c09f64fdcfcd525e7af8c59bca27c3c9c70cefb1c` |
| `3.12`             | `sha256:b20b51fc120b1efeaf5ee3f47627407061cf012a03d0e50cd18aa8d37ccdfaf8` |
| `3.12-dev`         | `sha256:62755ecb36685a3c96d4d74d469dd3ee7bf97aed3449aa10852ae298afa18551` |
| `3.12-fips`        | `sha256:19d415a123ce42fe56f348041fc032a87845d3555f792f56a94d7c8af798fb16` |
| `3.12-fips-dev`    | `sha256:b65e979a1992450af8f58195a74281f2606958559db662343bb487dbc31b1bf3` |
| `3.12-sfw-dev`     | `sha256:79b5d3ff3bfab162bd2dd01f603838c632cd4c92f4991f255db3b0682d078c86` |
| `3.12-sfw-ent-dev` | `sha256:2459c30ad882bffdb535acb225059f839f473d81698b4d7e8f27409aadcef644` |
| `3.13`             | `sha256:05827957dafc7b83633d56f24d9281525d3546a1d600eef90385c7212d3def5e` |
| `3.13-dev`         | `sha256:7933d16e50454c39bca6e935027166d5e5b05c6c03383dc2f58e8fe6e2440b7d` |
| `3.13-fips`        | `sha256:446fcd7abe26795afc796ccf8896cecf7aab0b4b717586814cd4c47cb5af6f73` |
| `3.13-fips-dev`    | `sha256:88b2ac6ce45cf42040824e495e29682ad40f5d5c6c8d9f3624d3c2e64c5194ae` |
| `3.13-sfw-dev`     | `sha256:f00c5f473673d4989c1c9a8fc001538e51f2eefa8fc122eba13b3ce70315d5a5` |
| `3.13-sfw-ent-dev` | `sha256:54d4c0f01690b83967aaf79f067c8e95dddae86f3440809d38dca36cedec76dc` |
| `3.14`             | `sha256:975fb771f0685d6e0aa1212813c6f0c8c5062e77aa4d34daa5aabbb9b9713f1d` |
| `3.14-dev`         | `sha256:1977c4a9624171ef582e641eb6f67adfc3f4b3ec0cb59345876f1928cda6f698` |
| `3.14-fips`        | `sha256:020d619de0cb0baa3531dccf61670c488a61ad7e359a01327be0888e44a1505c` |
| `3.14-fips-dev`    | `sha256:081e0b57de89256f5769c1122006634427733f29ed9e31f67147ec06f7a9ef5c` |
| `3.14-sfw-dev`     | `sha256:f54973f1424bb1e7ccf3976a67766b8b7aea38a438ac13d1ffab4da5f8ff510c` |
| `3.14-sfw-ent-dev` | `sha256:91fb629867ffbd61adfc844f5310d62e100bbb6679a263d2e677862103dab587` |
