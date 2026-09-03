## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Usage

The Forklift Validation service is designed to run as a sidecar or standalone deployment within the Forklift operator
stack. It starts an OPA REST server on port `8181` loaded with the Rego policies bundled at `/usr/share/opa/policies/`.

### Run as part of Forklift

In a standard Forklift deployment, this image is referenced in the Forklift operator manifest. The operator injects the
required TLS certificate paths via environment variables.

### TLS certificates

The entrypoint requires TLS certificates at startup. It reads three environment variables:

| Variable             | Required | Description                               |
| -------------------- | -------- | ----------------------------------------- |
| `TLS_CERT_FILE`      | yes      | Path to the server TLS certificate        |
| `TLS_KEY_FILE`       | yes      | Path to the server TLS private key        |
| `CA_TLS_CERTIFICATE` | no       | Path to the CA certificate for mutual TLS |

If `TLS_CERT_FILE` or `TLS_KEY_FILE` are not set to an existing file, the container exits with an error.

Mounted certificate and key files must be readable by the `nonroot` user (UID 65532). If you bind-mount TLS material
from the host or a Kubernetes secret volume, ensure file permissions allow the container user to read both paths (for
example, mode `0644` on the key file, not `0600` owned by root only).

### Run standalone for policy inspection

```sh
docker run --rm -p 8181:8181 \
  -v /path/to/certs:/certs:ro \
  -e TLS_CERT_FILE=/certs/tls.crt \
  -e TLS_KEY_FILE=/certs/tls.key \
  -e CA_TLS_CERTIFICATE=/certs/ca.crt \
  dhi.io/forklift-validation:2.12.1-alpine3.24
```

Query a policy directly:

```sh
curl -s https://localhost:8181/v1/data/io/konveyor/forklift/vmware/concerns \
  --cacert /path/to/certs/ca.crt \
  -H 'Content-Type: application/json' \
  -d '{"input": {"vm": {}}}'
```

### FIPS variant

Use the `-fips` tag when operating in a FIPS 140-3 environment:

```sh
docker run --rm -p 8181:8181 \
  -v /path/to/certs:/certs:ro \
  -e TLS_CERT_FILE=/certs/tls.crt \
  -e TLS_KEY_FILE=/certs/tls.key \
  dhi.io/forklift-validation:2.12.1-alpine3.24-fips
```

### Development variant

The `-dev` tag adds an APK package manager and runs as root for interactive debugging. Runtime and FIPS variants include
a minimal shell only so `/usr/bin/entrypoint.sh` can start; use `-dev` for shells, `apk`, and troubleshooting.

```sh
docker run --rm -it --entrypoint /bin/sh dhi.io/forklift-validation:2.12.1-alpine3.24-dev
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include an interactive shell or a package manager (a minimal shell is present only to run
    `/usr/bin/entrypoint.sh`)
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
| No shell           | Runtime images do not include an interactive shell or package manager. A minimal shell is bundled only to execute `/usr/bin/entrypoint.sh`. Use a `dev` image for interactive debugging, or Docker Debug to attach a shell at runtime.                                                                                       |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user, including TLS certificate and key paths referenced by `TLS_CERT_FILE` and `TLS_KEY_FILE`.                                                                         |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates. Server TLS for this image is configured separately via `TLS_CERT_FILE`, `TLS_KEY_FILE`, and optional `CA_TLS_CERTIFICATE`; mount paths must be readable by the nonroot user.                              |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Upstream and Docker Hardened Images both use `/usr/bin/entrypoint.sh`, which starts OPA on port `8181` with the bundled Rego policies. You must set `TLS_CERT_FILE` and `TLS_KEY_FILE` to existing, readable certificate paths before the container starts; otherwise the entrypoint exits with an error.                    |

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

The hardened images intended for runtime don't include an interactive shell or debugging tools. Runtime and FIPS
variants include a minimal shell only for `/usr/bin/entrypoint.sh`. The recommended method for debugging is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

When mounting TLS material for the entrypoint, both `TLS_CERT_FILE` and `TLS_KEY_FILE` must exist and be readable by UID
65532\. A common failure is a private key mounted with mode `0600` and owned by root on the host, which produces
`permission denied` inside the container.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't include an interactive shell or package manager. Runtime and FIPS
variants ship a minimal shell only so `/usr/bin/entrypoint.sh` can run. Use `dev` images for interactive shells and
`apk`, or Docker Debug to debug running containers.

### Entry point

Upstream and Docker Hardened Images use the same entry point: `/usr/bin/entrypoint.sh`. It validates `TLS_CERT_FILE` and
`TLS_KEY_FILE`, then starts OPA with the bundled policies on port `8181`. Use `docker inspect` if you need to confirm
the entry point in a specific tag.
