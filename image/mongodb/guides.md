## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a MongoDB instance

Note: MongoDB Docker Hardened Images are AMD64-tagged images. When running on ARM-based systems using the
`--platform linux/amd64` flag, the images will run under emulation, which can significantly impact performance.

Run the following command and replace `<tag>` with the image variant you want to run.

### Basic MongoDB instance

```bash
docker run -d \
  --name mongodb \
  -p 27017:27017 \
  dhi.io/mongodb:<tag>
```

This starts MongoDB without authentication.

Note: Runtime variants (without `-dev` in the tag) do not include shell access. Use `-dev` variants when you need shell
access for administrative tasks, or use Docker Debug for troubleshooting running containers.

### MongoDB instance with dev variant (includes shell access)

If you need shell access for administrative tasks, use the dev variant:

```bash
docker run -d \
  --name mongodb \
  -p 27017:27017 \
  dhi.io/mongodb:<tag>-dev
```

### MongoDB with persistent data

Use volumes to preserve your data across container restarts and upgrades.

```bash
docker run -d \
  --name mongodb \
  -p 27017:27017 \
  -v mongodb_data:/data/db \
   dhi.io/mongodb:<tag>
```

## Common MongoDB use cases

### Authentication Setup

MongoDB DHI requires manual authentication setup through a three-step process: create users, configure security, and
restart with auth enabled.

### Complete Setup Script

```bash
# 1. Start MongoDB
docker run -d --name mongodb -v mongodb_data:/data/db \
  dhi.io/mongodb:<tag>-dev

sleep 7

# 2. Create admin user
docker exec mongodb mongosh --eval "
  db.getSiblingDB('admin').createUser({
    user: 'admin',
    pwd: 'secure_password',
    roles: [{role: 'root', db: 'admin'}]
  })
"

# 3. Enable authentication
docker stop mongodb && docker rm mongodb

docker volume create mongodb_config
docker run --rm -v mongodb_config:/c dhi.io/alpine-base:<tag> sh -c 'cat > /c/mongod.conf << "EOF"
net:
  bindIp: 0.0.0.0
storage:
  dbPath: /data/db
security:
  authorization: enabled
EOF'

docker run -d --name mongodb -p 27017:27017 \
  -v mongodb_data:/data/db \
  -v mongodb_config:/etc/mongo:ro \
  dhi.io/mongodb:<tag>-dev \
  --config /etc/mongo/mongod.conf

sleep 7

# 4. Verify
docker exec mongodb mongosh -u admin -p secure_password \
  --authenticationDatabase admin \
  --eval "print('✓ Authenticated: ' + db.version())"
```

### Connect to MongoDB

Access MongoDB using mongosh either from inside the container or from your host machine.

```bash
# From container
docker exec -it mongodb mongosh -u admin -p secure_password --authenticationDatabase admin

# From host
mongosh "mongodb://admin:secure_password@localhost:27017/admin"
```

## Docker Official Images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official MongoDB             | Docker Hardened MongoDB                             |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt available                       | No package manager in runtime variants              |
| User            | Runs as mongodb user (UID 999)      | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
docker debug mongodb
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:mongodb \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/mongodb:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                             |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                  |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                 |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                         |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. MongoDB default port 27017 works without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                |

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

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
