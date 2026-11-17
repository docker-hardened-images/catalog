## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a Tomcat instance

Run the following command to run the Tomcat server. Replace `<tag>` with the image variant you want to run.

```
$ docker run -p 8080:8080 -d dhi.io/tomcat:<tag>
```

Note that visiting http://localhost:8080 will return a 404 as no webapps are loaded by default.

### Deploy a web application

There are two common ways to deploy a .war file.

The first way is to mount into `webapps/`:

```
$ docker run -p 8080:8080 \
    -v $(pwd)/myapp.war:/usr/local/tomcat/webapps/myapp.war \
    -d dhi.io/tomcat:<tag>
```

The second way is to build a new image that adds the `.war` file to `webapps/`:

```Dockerfile
FROM dhi.io/tomcat:<tag>
COPY myapp.war /usr/local/tomcat/webapps/
```

### Persist logs and configuration

The configuration files are available in `/usr/local/tomcat/conf/`.

To capture logs or provide your own Tomcat configuration files, mount a volume into the container:

```
$ docker run -p 8080:8080 \
    -v $(pwd)/logs:/usr/local/tomcat/logs \
    -v $(pwd)/server.xml:/usr/local/tomcat/conf/server.xml \
    -d dhi.io/tomcat:<tag>
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Tomcat                 | Docker Hardened Tomcat                              |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user in runtime variants            |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/<image-name>:<tag> /dbg/bin/sh
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

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. In attestations you will see two crypto module information blocks: one for OpenSSL FIPS
(system TLS) and one for the language runtime (for example, BouncyCastle FIPS in Java).

## Migrate to a Docker Hardened Image

Switching to the hardened Tomcat image does not require any special changes. You can use it as a drop-in replacement for
the standard Tomcat image in your existing workflows and configurations.

### Migration steps

1. Update your image reference. For example:

   - From: `tomcat:<tag>`
   - To: `dhi.io/tomcat:<tag>`

1. Review environment variables usage.

   Docker Hardened Tomcat images keep the same directory layout (`/usr/local/tomcat`) and default behavior as the
   standard image, so most mounts and configurations work unchanged. However, environment variables differ slightly:
   this image uses `JAVA_HOME` (Temurin) instead of the DOI's `JRE_HOME`. If your scripts reference `JRE_HOME`, switch
   to `JAVA_HOME` (or export `JRE_HOME=$JAVA_HOME` for compatibility).

1. Runtime variants run as a non-root user and do not include a package manager. In most Tomcat use cases, you won't
   need to install extra packages, just deploy your `.war` files as usual. If your application requires native libraries
   or build tools, use the `dev` variant in build stages to install them, and copy the built artifacts into a runtime
   image.

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
