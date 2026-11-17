## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Image contents

SPIFFE Helper is a utility that retrieves X.509 SVIDs and JWT SVIDs from the SPIFFE Workload API and writes them to disk
for workloads that cannot speak the Workload API directly. In daemon mode (the default), it continuously renews
certificates before they expire and optionally signals or re-runs a managed process when renewal occurs. In non-daemon
mode, it fetches certificates once and exits.

This image contains the `/spiffe-helper` binary. It runs as the nonroot user (uid 65532) and does not include a shell or
package manager. For full configuration reference and advanced usage, see the
[upstream documentation](https://github.com/spiffe/spiffe-helper).

### Run the spiffe-helper container

To display the version:

```console
$ docker run --rm dhi.io/spiffe-helper:<tag> -version
```

To display help:

```console
$ docker run --rm dhi.io/spiffe-helper:<tag> -help
```

To run with a configuration file and a shared SVID output volume:

```console
$ docker run --rm \
  -v /run/spire/sockets:/run/spire/sockets \
  -v /path/to/helper.conf:/etc/spiffe-helper/helper.conf:ro \
  -v /path/to/certs:/certs \
  dhi.io/spiffe-helper:<tag> -config /etc/spiffe-helper/helper.conf
```

Replace `/run/spire/sockets` with the host path where the SPIFFE Workload API socket is exposed, and `/path/to/certs`
with a host directory writable by uid 65532.

### Workload API socket

SPIFFE Helper connects to the SPIFFE Workload API through a Unix domain socket. The socket is typically provided by a
SPIRE Agent running on the same node, by a SPIFFE CSI driver, or by another Workload API implementation. You must mount
the socket into the container and configure the `agent_address` field in the config file to point to it.

For a SPIRE Agent socket at `/run/spire/sockets/agent.sock` on the host, add:

```console
-v /run/spire/sockets:/run/spire/sockets
```

And set in `helper.conf`:

```hcl
agent_address = "/run/spire/sockets/agent.sock"
```

### Configuration file

SPIFFE Helper requires an HCL configuration file. If `-config` is not specified, the binary looks for `helper.conf` in
the working directory. Pass the path explicitly with `-config /path/to/helper.conf`. A minimal configuration that
fetches X.509 SVIDs to `/certs` in daemon mode looks like:

```hcl
agent_address  = "/run/spire/sockets/agent.sock"
cert_dir       = "/certs"
svid_file_name = "svid.pem"
svid_key_file_name  = "svid_key.pem"
svid_bundle_file_name = "svid_bundle.pem"
daemon_mode    = true
```

For the full list of configuration options, see the
[upstream README](https://github.com/spiffe/spiffe-helper#configuration).

### SVID output paths

SPIFFE Helper writes certificate and key files to the `cert_dir` directory defined in the config file. Mount a host
directory or an emptyDir volume at that path and ensure it is writable by uid 65532. In Kubernetes, this is typically an
`emptyDir` shared between the SPIFFE Helper init or sidecar container and the application container.

### Health endpoint

The health endpoint is disabled by default. To enable it, add a `health_checks` block to `helper.conf`:

```hcl
health_checks {
  listener_enabled = true
  bind_port        = "8081"
  liveness_path    = "/live"
  readiness_path   = "/ready"
}
```

When enabled, expose the port with `-p 8081:8081` (or the equivalent Kubernetes `containerPort`) so that your
orchestrator can reach the liveness and readiness endpoints.

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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants. The SPIFFE Helper FIPS variant runs in
  lenient FIPS mode (`GODEBUG=fips140=on`) because the go-jose library used transitively by go-spiffe uses SHA-1 for JWK
  thumbprints, which is not permitted in strict mode.

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

The upstream `ghcr.io/spiffe/spiffe-helper` image also places the binary at `/spiffe-helper` and has an empty CMD, so
switching to `dhi.io/spiffe-helper` is a near-drop-in replacement for most deployments. One important runtime difference
is that the upstream image runs as root, while the Docker Hardened Image runs as the nonroot user with uid 65532.

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

If SPIFFE Helper exits with a permission error writing SVID files, verify that the `cert_dir` volume is writable by uid
65532\.

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
