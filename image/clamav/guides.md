## How to use this image

## Start a ClamAV container

Run the following command. Replace `<your-namespace>` with your organization's namespace and `<tag>` with the image
variant you want to run.

```bash
docker run --rm -it <your-namespace>/dhi-clamav:<tag>
```

## Common ClamAV use cases

### Update the virus database

The DHI ClamAV comes with two variants:

- the regular that contains the virus database at the time of the creation of the image
- the `-base` that does not contain the virus database.

In order to use the `-base` or to have an up to date virus database, you will need to run `freshclam`:

```bash
docker run -it --rm <you-namespace>/dhi-clamav:<tag> freshclam
```

By default, the virus database is stored within the running container in `/var/lib/clamav`. You can either use a volume
or a bind mount to share it or persist it across short-lived ClamAV containers.

With a volume, you will first create the volume and attach the container to it:

```bash
docker volume create clam_db

docker run -it --rm \
    --mount source=clam_db,target=/var/lib/clamav \
    <you-namespace>/dhi-clamav:<tag>
```

With a bind mount, you will simply map a local directory to a path within the container

```bash
docker run -it --rm \
    --mount type=bind,source=/path/to/databases,target=/var/lib/clamav \
    <you-namespace>/dhi-clamav:<tag>
```

### Running Clam(D)Scan

To scan files, mount the folder to scan as a bind mount to `/scandir` and run `clamscan`.

**Note**: `clamscan` needs the virus database to be in the image. Either use the `-base` variant of the image or update
the database first.

```bash
docker run -it --rm \
    --mount type=bind,source=/path/to/scan,target=/scandir \
    <you-namespace>/dhi-clamav:<tag> \
    clamscan /scandir
```

ClamDScan can be used by exposing a TCP/UDP port or unix socket.

```bash
docker run -it --rm \
    --mount type=bind,source=/path/to/scan,target=/scandir \
    --mount type=bind,source=/var/lib/docker/data/clamav/sockets/,target=/run/clamav/ \
    <you-namespace>/dhi-clamav:<tag>
```

You can find more documentation about using ClamAV at https://docs.clamav.net/manual/Installing/Docker.html. Simply
replace the image name by `<you-namespace>/dhi-clamav:<tag>`.

## Image variants

Docker Hardened Images typically come in different variants depending on their intended use. Image variants are
identified by their tag. For ClamAV DHI images, 3 runtime variants are currently available:

- a regular, preloaded with the signature databases available at time of the build of the image.
- a `-base`, not preloaded with the signature databases.
- a regular FIPS variant from version 1.5.

Runtime variants are designed to run your application in production. These images are intended to be used directly.
Runtime variants typically:

- Run as a nonroot user
- Do not include package managers
- Contain only the minimal set of libraries needed to run the app

Note: No `dev` variant exists for ClamAV DHI.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. Docker Hardened Python images include FIPS-compliant variants for environments requiring
Federal Information Processing Standards compliance.

## Migrate to a Docker Hardened Image

Important Note: This is a pre-built, ready-to-run Grist application. Use it directly via docker run rather than as a
base image in a Dockerfile. Most migration scenarios below do not apply to this image.

| Item               | Migration note                                                                                                              |
| :----------------- | :-------------------------------------------------------------------------------------------------------------------------- |
| Base image         | This is a pre-built application - use directly via docker run, not as a base image in Dockerfile.                           |
| Package management | No package managers present (no apt, apk, yum). Cannot install additional packages at runtime.                              |
| Nonroot user       | Runs as UID 65532 (user: nonroot). Writable directories: /persist and /tmp. Application directory /grist is read-only.      |
| Multi-stage build  | Only one variant exists (1.7.3-debian13). No dev or static variants available.                                              |
| TLS certificates   | Node.js includes its own certificate bundle, so HTTPS connections work correctly. No action needed for Grist functionality. |
| Ports              | Pre-configured to listen on port 8484 (non-privileged). Compatible with nonroot user. No configuration needed.              |
| Entry point        | Custom entrypoint configured: `/grist/sandbox/docker_entrypoint.sh` with `CMD: node /grist/sandbox/supervisor.mjs`          |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshoot migration

### General debugging

Docker Hardened Images provide robust debugging capabilities through **Docker Debug**, which attaches comprehensive
debugging tools to running containers while maintaining the security benefits of minimal runtime images.

**Docker Debug** provides a shell, common debugging tools, and lets you install additional tools in an ephemeral,
writable layer that only exists during the debugging session:

```bash
docker debug <container-name>
```

**Docker Debug advantages:**

- Full debugging environment with shells and tools
- Temporary, secure debugging layer that doesn't modify the runtime container
- Install additional debugging tools as needed during the session
- Perfect for troubleshooting DHI containers while preserving security

### Permissions

Runtime image variants run as the nonroot user. Ensure that necessary files and directories are accessible to that user.
You may need to copy files to different directories or change permissions so your application running as a nonroot user
can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure your
Rust applications to listen on ports 8000, 8080, or other ports above 1024.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
