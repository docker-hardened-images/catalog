## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Using the OpenSCAP Docker Hardened Image (General Use)

This Docker Hardened Image is a drop-in replacement for the oscap CLI tool. It can evaluate both XCCDF benchmarks and
OVAL definitions and generate the appropriate results.

OpenSCAP can also be used to validate the STIG posture for all Docker Hardened Images.

#### Running OpenSCAP

To test this image, you can run oscap and point it to the DHI GPOS SRG file that is embedded in the image itself:

```console
docker run --rm -it dhi.io/openscap:<tag> info /opt/docker/gpos/xml/scap/ssg/content/ssg-dhi-gpos-ds.xml
```

```console
Document type: Source Data Stream
Imported: 2025-11-16T18:03:16

Stream: scap_org.open-scap_datastream_from_xccdf_all-resolved-xccdf-v3r2.xml
...
```

Use the --profile option to obtain info about a given profile:

```console
docker run --rm -it dhi.io/openscap:<tag> info --profile <profile> <SCAP file>
```

To evaluate content against a set of OVAL rules, use the oscap validate command and examine the exit code, for example:

```console
docker run --rm -it -v $(pwd)/extra-content:/extra-content dhi.io/openscap:<tag> oval validate <SCAP file> && echo "ok" || echo "exit code = $? validation failure"
```

To customize evaluation even further you could mount the extra content to be evaluated, and customize the dictionary and
STIG profile along with the output directories.

```console
docker run --rm -it \
  -v $(pwd)/out:/out \
  -v $(pwd)/extra-content:/extra-content \
  -v $(pwd)/stigs:/stigs \
  --entrypoint oscap dhi.io/openscap:<tag> \
  xccdf eval --profile <profile> \
  --results /out/results.xml \
  --report /out/results.html \
  --cpe /stigs/<dictionary> \
  /stigs/<SCAP file>
```

### Using the OpenSCAP Docker Hardened Image with DHI images

Following are several sets of instructions that will help you scanning DHI images for compliance with all frameworks
supporting oval rules, like for example STIG.

#### Obtaining the DHI GPOS STIG Profile

The DHI GPOS STIG Profile can be obtained from the
[OpenSCAP DHI](https://github.com/docker-hardened-images/catalog/blob/main/image/openscap/config/ssg-dhi-gpos-ds.xml)
image at GitHub.

#### Running OpenSCAP on a DHI image from registry

Note: You need to use the `dev` variant for this functionality to work as it requires root access.

You can use the oscap tool to evaluate the STIG posture on any of the DHI images. The OpenSCAP DHI image includes
`oscap-docker` a Python utility that can be used to evaluate any Docker container or image. You can point this tool to a
registry image and use an experimental Docker feature that allows to mount a shell on top of an existing image. This
happens automatically if you invoke `oscap-docker` pointing to the image.

```console
# The image must be pulled first
docker pull dhi.io/airflow:3-fips

# Scan the image directly
docker run --rm -it --pid=host -v "$HOME/.docker/run/docker.sock:/var/run/docker.sock" -v $(pwd)/out:/out --entrypoint oscap-docker dhi/openscap:<tag>-dev image dhi.io/airflow:3-fips xccdf eval --profile xccdf_dhi-gpos_profile_.check --results /out/oval-results.xml --report /out/compliance-report.html /opt/docker/gpos/xml/scap/ssg/content/ssg-dhi-gpos-ds.xml
```

The above command scans the image against the DHI GPOS. You'll get an output like this:

```console
Creating a temporary container for the image...
...
Title   The operating system must prohibit user installation of
system software without explicit privileged status.
Rule    xccdf_mil.disa.stig_rule_SV-203716r982210_rule
Ident   CCI-003980
Result  pass

Title   The operating system must include only approved
trust anchors in trust stores or certificate stores managed by the
organization.
Rule    xccdf_mil.disa.stig_rule_SV-263659r982563_rule
Ident   CCI-004909
Result  pass

Temporary container 61ac917501f0ed65f2c17abbb09bf8918db63764d7d78e0004852a335d2197ac cleaned
Cleaning temporary extracted container...
```

A generated report will be available at `out/report.html` for you to browse. This report contains the evaluation results
against the `Docker Hardened Image - Alpine 3.22/Debian 12/13 GPOS STIG Profile`.

#### Running OpenSCAP on a DHI running container

You can do the same technique on any running container. Below we start the postgres FIPS image and mount busybox on top
to run a sleep command immediately after. This allows us to have a latent container that we can scan:

```console
docker pull busybox:uclibc
docker run --rm --name dhi_postgres_16-alpine3.22-fips -u 0:0 --mount type=image,source=busybox:uclibc,target=/busybox --entrypoint /busybox/bin/sleep dhi/postgres:16-alpine3.22-fips "infinite" &
```

With the above command we have now the DHI image running sleep. We can now point DHI OpenSCAP to that container.

```console
docker run --rm --pid=host -v "$HOME/.docker/run/docker.sock:/var/run/docker.sock" -v $(pwd)/out:/out dhi.io/openscap:<dev-tag> dhi_postgres_16-alpine3.22-fips
```

```console
Container dhi_postgres_16-alpine3.22-fips is running, using its existing mount...
Docker container dhi_postgres_16-alpine3.22-fips ready to be scanned.
--- Starting Evaluation ---
....
.... many more checks...
....
Title   The operating system must prohibit user installation of
system software without explicit privileged status.
Rule    xccdf_._rule_V_203716
Result  pass

Title   The operating system must include only approved
trust anchors in trust stores or certificate stores managed by the
organization.
Rule    xccdf_._rule_V_263659
Result  pass
```

#### Scanning a custom application built on top of a DHI image

Following with the above examples, we can download the DHI Stig profile and apply it to a custom application built on
top of DHI. To make the example complete, first we will build an application on top of DHI's Python FIPS.

Create a new directory and use the following Dockerfile to get started.

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

    print("Waiting 10 minutes for OpenSCAP scan...")

if __name__ == "__main__":
    main()
```

```
openai
numpy
pandas
```

Run the following commands to build and run the sample app mounting busybox on it.

```console
docker build -t my-python-app .

docker run --rm --name my-running-app -u 0:0 --mount type=image,source=busybox:uclibc,target=/busybox --entrypoint /busybox/bin/sleep my-python-app "infinite" &
```

Finally, run the following to execute the STIG profile that we downloaded earlier on this new DHI FIPS Python
application that was just created.

```console
mkdir -p out stigs
wget https://raw.githubusercontent.com/docker-hardened-images/catalog/refs/heads/main/image/openscap/config/ssg-dhi-gpos-ds.xml -O stigs/ssg-dhi-gpos-ds.xml
docker run --rm --pid=host \
           -v /var/run/docker.sock:/var/run/docker.sock \
           -v $(pwd)/out:/out \
           -v $(pwd)/stigs:/stigs \
           --entrypoint oscap-docker \
           dhi.io/openscap:<dev-tag> \
           container my-running-app \
           xccdf eval \
           --profile xccdf_dhi-gpos_profile_.check \
           --results /out/oval-results.xml \
           --report /out/compliance-report.html \
           /stigs/ssg-dhi-gpos-ds.xml


Docker container my-running-app ready to be scanned.
--- Starting Evaluation ---

Title   The operating system must prohibit the use or
connection of
unauthorized hardware
components.
...
...
Title   The operating system must prohibit user installation of
system software without explicit privileged status.
Rule    xccdf_._rule_V_203716
Result  pass

Title   The operating system must include only approved
trust anchors in trust stores or certificate stores managed by the
organization.
Rule    xccdf_._rule_V_263659
Result  pass
```

You can easily determine if the evaluation has passed or failed by looking at the report and find checks that have
failed. For automated validation, inspecting the exit code of the docker run command is the most reliable way to find
that there has been broken rules.

#### Scanning a DHI image against other set of security rules

DHI images or derivatives can be scanned against other set of rules following the same process described in the above
examples. Simply replace the DHI security guide with your own file:

```console
docker run --rm --pid=host \
           -v /var/run/docker.sock:/var/run/docker.sock \
           -v $(pwd)/out:/out \
           -v $(pwd)/stigs:/stigs \
           --entrypoint oscap-docker \
           dhi.io/openscap:<dev-tag> \
           container my-running-app \
           xccdf eval \
           --profile xccdf_dhi-gpos_profile_.check \
           --results /out/oval-results.xml \
           --report /out/compliance-report.html \
           /stigs/<SCAP File>
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened OpenSCAP       | Docker Hardened OpenSCAP               |
| --------------- | --------------------------- | -------------------------------------- |
| Base image      | Alpine Linux                | Debian 13 hardened base                |
| Security        | Standard Alpine packages    | Security patches + signed metadata     |
| Shell access    | Shell available (`/bin/sh`) | No shell                               |
| Package manager | `apt` available             | No package manager                     |
| User            | Runs as `root` (UID 0)      | Runs as `nonroot` (UID 65532)          |
| Build process   | Pre-compiled binaries       | Built from source with verified commit |
| Debugging       | Shell + basic tools         | Docker Debug or Image Mount            |
| SBOM            | Not included                | Complete SBOM included                 |
| CVE scanning    | Not guaranteed              | Published with near-zero known CVEs    |
| Tooling         | Includes docker-oscap       | Only includes oscap                    |

## Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Application-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/openscap:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a non-root user (UID 65532)
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

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                            |
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
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the **Tags** tab for this repository. To view what packages are already installed in an image variant, select
   the **Tags** tab for this repository, and then select a tag.

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

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The default
ports are:

- Master: 9333 (HTTP), 19333 (gRPC)
- Volume: 8080 (HTTP), 18080 (gRPC)
- Filer: 8888 (HTTP), 18888 (gRPC)
- S3: 8333
- WebDAV: 7333

No configuration changes are needed to run SeaweedFS as a nonroot user.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
