## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Run a Grist container

To run a Grist container, run the following command. Replace `<tag>` with the image variant you want to run.

```
$ docker run -p 8484:8484 dhi.io/grist:<tag>
```

Then visit `http://localhost:8484` in your browser.

### Run with persistent data

```
docker run -d \
  -p 8484:8484 \
  -v grist-data:/persist \
  -e GRIST_DEFAULT_EMAIL=admin@company.com \
  dhi.io/grist:<tag>
```

## Docker Compose example

```
services:
  grist:
    image: dhi.io/grist:<tag>
    ports:
      - "8484:8484"
    volumes:
      - grist-data:/persist
    environment:
      - GRIST_DEFAULT_EMAIL=admin@company.com
      - GRIST_SINGLE_ORG=myorg
    restart: unless-stopped

volumes:
  grist-data:
```

## Image variants

Docker Hardened Images typically come in different variants depending on their intended use. Image variants are
identified by their tag. For Grist DHI images, only ONE variant is currently available:

- Tag: `1.7.3-debian13` (runtime variant)

Runtime variants are designed to run your application in production. These images are intended to be used directly.
Runtime variants typically:

- Run as a nonroot user
- Do not include package managers
- Contain only the minimal set of libraries needed to run the app

Note: No `dev` variant exists for Grist DHI.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

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
