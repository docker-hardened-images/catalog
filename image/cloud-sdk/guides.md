## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this cloud-sdk image

Every cloud-sdk image bundles the Google Cloud CLI tools:

- **gcloud** — Primary Google Cloud CLI for authenticating and managing Google Cloud Platform resources.
- **bq** — Command-line tool for creating and managing BigQuery datasets, tables, and jobs.
- **gsutil** — Command-line tool for creating and managing Cloud Storage buckets and objects.

The `-emulators` flavor additionally bundles Google's local service emulators:

- **Datastore emulator**
- **Firestore emulator**
- **Pub/Sub emulator**
- **Bigtable emulator**
- **Spanner emulator** — `linux/amd64` only; Google publishes no arm64 build.

Unlike most hardened runtime images, the runtime variants keep a shell: the `gcloud`, `gsutil`, and `bq` launchers are
shell scripts. They still contain no package manager.

Compared with upstream `google/cloud-sdk`, no other optional gcloud components are included — notably `kubectl`,
`gke-gcloud-auth-plugin`, `cbt`, `kpt`, and the App Engine (`app-engine-*`) components. GKE workflows that rely on
`kubectl` or `gke-gcloud-auth-plugin` must source those separately (for example, from a dedicated hardened image).

### Run the cloud-sdk container

Commands pass through directly, matching upstream's lack of an entrypoint. With no command, the image runs
`gcloud version`:

```bash
docker run --rm dhi.io/cloud-sdk:<tag>
```

> **Migrating from `google/cloud-sdk`?** The upstream image's default command is an interactive shell (`bash`), whereas
> this image defaults to `gcloud version`. Pass an explicit command (e.g. `bash` on the `-dev` variant, or the emulator
> start command you need) rather than relying on the default landing you in a shell.

To see all available `gcloud` commands:

```bash
docker run --rm dhi.io/cloud-sdk:<tag> gcloud help
```

`bq` and `gsutil` are also on the `PATH`:

```bash
docker run --rm dhi.io/cloud-sdk:<tag> bq version
docker run --rm dhi.io/cloud-sdk:<tag> gsutil version
```

Usage reporting is disabled by default for non-interactive use.

### Run a local Google Cloud emulator

The emulators ship only in the `-emulators` flavor — use a tag ending in `-emulators` for everything in this section.
Each emulator listens on a container port that you publish with `docker run -p`. Point your application's client
libraries at the emulator using the corresponding `*_EMULATOR_HOST` environment variable instead of real GCP
credentials.

| Emulator                     | Start command                                                                                              | Default port(s)          | Client env var            |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------ | ------------------------- |
| Pub/Sub                      | `gcloud beta emulators pubsub start --host-port=0.0.0.0:8085`                                              | 8085                     | `PUBSUB_EMULATOR_HOST`    |
| Firestore                    | `gcloud beta emulators firestore start --host-port=0.0.0.0:8080`                                           | 8080                     | `FIRESTORE_EMULATOR_HOST` |
| Datastore                    | `gcloud beta emulators datastore start --host-port=0.0.0.0:8081 --no-store-on-disk --project=demo-project` | 8081                     | `DATASTORE_EMULATOR_HOST` |
| Bigtable                     | `gcloud beta emulators bigtable start --host-port=0.0.0.0:8086`                                            | 8086                     | `BIGTABLE_EMULATOR_HOST`  |
| Spanner (`linux/amd64` only) | `gcloud beta emulators spanner start`                                                                      | 9010 (gRPC), 9020 (REST) | `SPANNER_EMULATOR_HOST`   |

The emulators are unauthenticated by design: anyone who can reach a published port has full read and write access to the
emulated data. The `--host-port=0.0.0.0:<port>` in the start commands refers to interfaces inside the container and is
required for a published port to reach the emulator; on the host side, bind published ports to loopback
(`-p 127.0.0.1:<port>:<port>`) unless other machines genuinely need access.

For example, to run the Pub/Sub emulator in the background and point a client library at it:

```bash
docker run --rm -d -p 127.0.0.1:8085:8085 \
  dhi.io/cloud-sdk:<tag>-emulators \
  gcloud beta emulators pubsub start --host-port=0.0.0.0:8085

export PUBSUB_EMULATOR_HOST=localhost:8085
```

The Spanner emulator has no `linux/arm64` build — on Apple Silicon or other `arm64` hosts, pass `--platform linux/amd64`
to `docker run`. The other four emulators support both architectures.

The Java-based emulators run on Eclipse Temurin 21.

### Use an emulator with Docker Compose

```yaml
services:
  pubsub-emulator:
    image: dhi.io/cloud-sdk:<tag>-emulators
    command: ["gcloud", "beta", "emulators", "pubsub", "start", "--host-port=0.0.0.0:8085"]
    ports:
      - "127.0.0.1:8085:8085"

  app:
    image: my-app:latest
    environment:
      PUBSUB_EMULATOR_HOST: pubsub-emulator:8085
    depends_on:
      - pubsub-emulator
```

### Persist gcloud configuration and credentials

`gcloud` writes configuration and credentials to `$HOME/.config/gcloud`. Mount a named volume to persist them:

```bash
docker run --rm -it \
  -v gcloud-config:/home/nonroot/.config/gcloud \
  dhi.io/cloud-sdk:<tag> gcloud auth login
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager, except where an upstream runtime contract requires a shell (this image
    keeps `bash` because the `gcloud`, `gsutil`, and `bq` launchers are shell scripts; it has no package manager)
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

  In this image, gcloud runs on the system Python, whose `ssl` and `hashlib` modules link the FIPS-configured OpenSSL.
  This covers TLS for gcloud's vendored HTTP stacks (httplib2, requests, urllib3), which all use the interpreter's `ssl`
  module. One exception: signing with a service-account JSON key uses gcloud's vendored pure-Python `rsa` library, which
  is not a FIPS-validated module — prefer access-token or workload-identity flows in FIPS-bound environments.

  There is no `-emulators-fips` variant. The emulators are local development tools whose crypto does not route through
  the system OpenSSL (the Datastore and Firestore emulators use the JVM's TLS stack, the Pub/Sub emulator bundles its
  own BoringSSL via netty-tcnative, the Spanner emulator statically links BoringSSL, and the Bigtable emulator uses Go's
  `crypto/tls`), so a FIPS tag on that flavor would be misleading.

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
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. This image is an exception: `bash` is included because the `gcloud`, `gsutil`, and `bq` launchers are shell scripts. Use dev images in build stages for general shell-based build steps.                                                            |
| gcloud config      | Upstream stores config under `/root/.config` (often mounted as a volume). This image runs as `nonroot`, so mount or copy credentials to `/home/nonroot/.config/gcloud` instead — mounts that still target `/root/.config` will not be picked up.                                                                             |
| gcloud components  | Only `gcloud`, `bq`, and `gsutil` are included (plus the emulators in the `-emulators` flavor). Upstream's `kubectl`, `gke-gcloud-auth-plugin`, `cbt`, `kpt`, and App Engine components are not — GKE workflows must add `kubectl` and `gke-gcloud-auth-plugin` from another source.                                         |

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

By default, image variants intended for runtime don't contain a shell. This image includes `bash` only because the
`gcloud`, `gsutil`, and `bq` launchers are shell scripts, and should not be treated like a dev image. Use `dev` images
in build stages to run shell commands and use Docker Debug for interactive troubleshooting.

### Slow gsutil transfers (no compiled crcmod)

Upstream's `google/cloud-sdk` image installs the compiled `python3-crcmod` extension. This image does not (no hardened
package is available), so `gsutil` falls back to a slower pure-Python CRC32C implementation and prints a warning during
`cp` and `rsync`. Transfers remain correct — only integrity-check throughput is affected.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
