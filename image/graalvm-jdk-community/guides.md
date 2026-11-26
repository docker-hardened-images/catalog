## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Upstream documentation is at https://www.graalvm.org/. This image is GraalVM Community Edition, not Oracle GraalVM.

### What's included in this GraalVM Community Edition JDK image

This Docker Hardened GraalVM Community Edition JDK image includes:

- `java` — Java launcher for the GraalVM Community Edition JDK
- `javac` — Java compiler included with the GraalVM Community Edition JDK
- `native-image` — GraalVM native-image utility. Building an executable needs a dev tag, which includes the C compiler.
  Alpine dev tags on linux/amd64 pass `--libc=musl` and `--native-compiler-path=/usr/bin/gcc`. Alpine linux/arm64 cannot
  build a musl executable: GraalVM refuses that target, so use a Debian dev tag there. A tag that includes `fips` uses
  that same command on the architectures that support it. `native-image` does not pass `JAVA_TOOL_OPTIONS` to its
  builder, so the image command adds the FIPS bootclasspath and truststore there. `java` stays in approved-only mode.

`native-image-configure`, `native-image-utils`, and `jnativescan` are also on `PATH`. `native-image-configure` and
`native-image-utils` are bash launchers.

`JAVA_HOME` is `/usr/lib64/graalvm/graalvm-community-java25i<N>` for innovation release N, a symlink to
`/usr/lib/graalvm-jdk-community-25`. Run `docker inspect` to read it for a tag. The working directory is `/app`, which
is writable by the runtime user, uid 65532.

## Start a GraalVM Community Edition JDK image

The image has no entrypoint. Pass `java`, `javac`, or `native-image` as the command.

A runtime tag runs `java --version` when you pass no arguments. That prints the JDK version and `GraalVM CE` followed by
the tracked innovation release. A dev tag runs `/bin/bash`, so a `docker run` with no arguments starts a shell. Extra
arguments replace that command, which is why `java --version` still runs `java` on a dev tag.

```bash
docker run --rm dhi.io/graalvm-jdk-community:<tag> java --version
```

```bash
docker run --rm dhi.io/graalvm-jdk-community:<tag> native-image --version
```

To open a shell, use a dev tag:

```bash
docker run --rm -it dhi.io/graalvm-jdk-community:<tag>
```

## Common GraalVM Community Edition JDK use cases

### Compile and run a class

Use a runtime tag. The process runs as uid 65532. The directory you mount on `/app` has to be writable by that user, or
`javac` cannot write the class file.

```bash
mkdir -p hello
cat > hello/Hello.java << 'EOF'
public class Hello {
    public static void main(String[] args) {
        System.out.println("Hello from GraalVM");
    }
}
EOF
chmod 777 hello

docker run --rm -v "$PWD/hello":/app -w /app dhi.io/graalvm-jdk-community:<tag> javac Hello.java
docker run --rm -v "$PWD/hello":/app -w /app dhi.io/graalvm-jdk-community:<tag> java Hello
```

### Build a native executable

`native-image` links with a C compiler. A dev tag includes one. Runtime tags do not, so link on a dev tag. Compile
`Hello.class` first, as in the previous example.

On a Debian dev tag, including a Debian tag that includes `fips`, the image name is the second argument (`hello` writes
`./hello`):

```bash
docker run --rm -v "$PWD/hello":/app -w /app dhi.io/graalvm-jdk-community:<tag> native-image Hello hello
```

On an Alpine dev tag on linux/amd64, including an Alpine tag that includes `fips`, select the musl toolchain:

```bash
docker run --rm -v "$PWD/hello":/app -w /app dhi.io/graalvm-jdk-community:<tag> native-image --libc=musl --native-compiler-path=/usr/bin/gcc Hello hello
```

Alpine linux/arm64 does not build musl native executables. GraalVM reports that building on LINUX_AARCH64 for musl is
not supported on that platform. Use a Debian dev tag on linux/arm64.

Run that executable with a runtime tag of the same distro:

```bash
docker run --rm -v "$PWD/hello":/app -w /app dhi.io/graalvm-jdk-community:<tag> ./hello
```

## Non-hardened images vs. Docker Hardened Images

This image replaces the compact `ghcr.io/graalvm/jdk-community` image (the `25i<N>` innovation tags and `latest`).

- Runtime images run as uid 65532. The upstream image runs as root. A directory mounted for `javac` output must be
  writable by uid 65532.
- This image includes `native-image`, and `native-image-configure` and `native-image-utils` are bash launchers. The
  compact upstream image omits `native-image`. The runtime image includes `bash` for those launchers.
- Catalog tag `25` tracks the current GraalVM Community Edition innovation release. The upstream tag
  `ghcr.io/graalvm/jdk-community:25` can lag that innovation line.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
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

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

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
