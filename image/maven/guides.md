## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a Maven build

Run the following command to execute Maven commands using a Docker Hardened Image. Replace `<tag>` with the image
variant you want to run.

```bash
$ docker run --rm dhi.io/maven:<tag>-dev --version
```

**Important**: Maven DHI images have `mvn` as their ENTRYPOINT. When using `docker run`, omit `mvn` from your commands.
In Dockerfiles, use `RUN mvn ...` as normal since RUN commands execute in shell context.

## Common Maven use cases

### Build a Maven project

Build your Maven project by mounting your source code and running Maven commands:

```bash
$ docker run --rm -v "$(pwd)":/app -w /app dhi.io/maven:<tag>-dev clean compile
```

### Build and package application artifacts

Create application artifacts like JAR or WAR files by building your Maven project:

```bash
$ docker run --rm -v "$(pwd)":/app -w /app dhi.io/maven:<tag>-dev clean package
```

## Build and run with Multi-stage Dockerfile

**Important**: Maven Docker Hardened Images are build-only tools. They contain no runtime variants because Maven builds
applications but doesn't run them. You must use multi-stage Dockerfiles to copy build artifacts to appropriate runtime
images.

This example demonstrates building the Spring Pet Clinic application using Maven Docker Hardened Images. Pet Clinic is a
canonical Spring Boot sample application that showcases typical enterprise Java development patterns.

### Clone and build PetClinic app

```
# Clone the Spring Pet Clinic repository
$ git clone https://github.com/spring-projects/spring-petclinic.git
$ cd spring-petclinic

# Build using Maven DHI
docker run --rm \
    -v "$(pwd)":/app -w /app \
    -v maven-repo:/root/.m2 \
    dhi.io/maven:<tag>-dev \
    clean package -DskipTests
```

Create a `Dockerfile` in the Pet Clinic directory:

```dockerfile
# syntax=docker/dockerfile:1
# Build stage - Maven DHI for building Pet Clinic
FROM dhi.io/maven:<tag>-dev AS build

WORKDIR /app

# Copy Maven files for dependency caching
COPY .mvn/ .mvn
COPY mvnw pom.xml ./

# Download dependencies (cached layer)
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the Pet Clinic application
RUN --mount=type=cache,target=/root/.m2 \
    mvn clean package -DskipTests -B

# Runtime stage - JRE for running Pet Clinic
FROM eclipse-temurin:<tag> AS runtime

# Create non-root user for security
RUN addgroup -g 1001 petclinic && \
    adduser -u 1001 -G petclinic -s /bin/sh -D petclinic

WORKDIR /app

# Copy the built JAR from build stage
COPY --from=build /app/target/spring-petclinic-*.jar app.jar

# Change ownership to petclinic user
RUN chown petclinic:petclinic app.jar

USER petclinic

# Pet Clinic runs on port 8080 by default
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Build and run Pet Clinic

```
# Build the Docker image
$ docker build -t petclinic-hardened .

# Run Pet Clinic
$ docker run --rm -p 8080:8080 --name petclinic petclinic-hardened

# Access Pet Clinic at http://localhost:8080
```

## Non-hardened images vs Docker Hardened Images

| Feature          | Docker Official Maven                                        | Docker Hardened Maven                                                         |
| ---------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| Security         | Standard base with common utilities                          | Custom hardened Debian with security patches                                  |
| Shell access     | Direct shell access                                          | Full shell access (requires ENTRYPOINT override)                              |
| Package manager  | Full package managers (apt, dpkg)                            | **No package managers (completely removed)**                                  |
| User             | Runs as root by default                                      | Runs as root (build environment)                                              |
| Attack surface   | Large (424+ utilities, full Ubuntu/Debian)                   | **Minimal (129 utilities, 70% fewer than standard)**                          |
| Runtime variants | Available for some use cases                                 | **Not available - build-only tool**                                           |
| Debugging        | Traditional shell debugging                                  | Use Docker Debug or ENTRYPOINT override                                       |
| Utilities        | Full development toolchain (curl, wget, git, vim, tar, make) | **Extremely minimal (no curl, wget, git, vim, nano, tar, gzip, unzip, make)** |

### Why such extreme minimization?

Docker Hardened Maven images prioritize security through aggressive minimalism:

- **Complete package manager removal**: No way to install additional software during builds
- **Utility reduction**: 70% fewer binaries than standard images (129 vs 424+)
- **Custom hardened OS**: Purpose-built "Docker Hardened Images (Debian)" not standard distributions
- **Essential-only toolset**: Only Maven, JDK, and core build utilities included

The hardened images focus exclusively on providing a secure, minimal Maven build environment. After Maven compiles and
packages your application, you run the resulting artifacts with appropriate runtime environments.

## Image variants

Docker Hardened Maven images are **build-time only**. All variants include `dev` in the tag name and are designed for
use in build stages of multi-stage Dockerfiles.

### Available variants

Maven DHI images follow this tag pattern: `<maven-version>-jdk<jdk-version>-<os>-dev`

**Maven versions:**

- `3.9.11` - Specific patch version (recommended for production)
- `3.9` - Latest patch of 3.9 series
- `3` - Latest minor and patch version

**JDK versions:**

- `jdk17` - Java 17 LTS (mature, stable)
- `jdk21` - Java 21 LTS (recommended for new projects)
- `jdk23` - Java 23 (latest features)

**Operating systems:**

- `debian13` - Debian-based (default, ~647MB uncompressed)
- `alpine3.22` - Alpine-based (~578MB uncompressed, ~69MB smaller)

## Migrate to a Docker Hardened Image

To migrate your Maven builds to Docker Hardened Images, you must update your Dockerfile and build process. Since Maven
DHI images are build-only, **you must use multi-stage builds**.

| Item                    | Migration note                                                                              |
| ----------------------- | ------------------------------------------------------------------------------------------- |
| Base image              | Replace Maven base images with Docker Hardened Maven dev images in build stages only        |
| Multi-stage required    | Maven DHI images are build-only. Use multi-stage builds to copy artifacts to runtime images |
| Package management      | Package managers are completely removed (in all dev variants)                               |
| Build user              | Maven DHI images run as root during build (appropriate for build environments)              |
| Dependency caching      | Use Docker cache mounts for `/root/.m2` to persist Maven local repository                   |
| Settings files          | Copy or mount Maven settings.xml if using custom repositories                               |
| Runtime image selection | Choose appropriate JRE/JDK runtime images that match your build JDK version                 |
| Entry point             | Runtime images define entry points; Maven DHI build images use `mvn` as ENTRYPOINT          |

### Migration process

1. **Identify your build requirements**

   Choose the appropriate Maven DHI dev variant based on your needs:

   - JDK version matching your application requirements
   - OS preference (Debian for compatibility, Alpine for size)
   - Maven version pinning strategy

1. **Convert to multi-stage build**

   Update your Dockerfile to use Maven DHI dev variant in the build stage:

   ```dockerfile
   # Build stage
   FROM dhi.io/maven:<tag>-dev AS build
   # ... Maven build commands ...

   # Runtime stage
   FROM eclipse-temurin:<tag> AS runtime
   COPY --from=build /app/target/app.jar .
   # ... runtime configuration ...
   ```

1. **Optimize dependency caching**

   Copy `pom.xml` before source code and use cache mounts:

   ```dockerfile
   COPY pom.xml .
   RUN --mount=type=cache,target=/root/.m2 mvn dependency:go-offline
   COPY src ./src
   RUN --mount=type=cache,target=/root/.m2 mvn package
   ```

1. **Select appropriate runtime image**

   Choose runtime images that match your build environment:

   - Same JDK major version (21 in build → JRE 21 in runtime)
   - Consider security and size requirements
   - Ensure runtime image supports your application type

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

Maven DHI images are build-only tools and contain shell access via ENTRYPOINT override. The recommended method for
debugging applications built with Docker Hardened Images is to use Docker Debug to attach to these containers. Docker
Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that
only exists during the debugging session.

### Permisions

Maven DHI images run as the root user during builds (appropriate for build environments). When copying build artifacts
to runtime stages, ensure that necessary files and directories have appropriate permissions for the runtime image's user
context, as runtime images typically run as nonroot users.

### Privileged Ports

Applications built with Maven DHI will typically run in runtime images that use nonroot users by default. As a result,
your applications can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions
older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container,
even if you map it to a lower port on the host. For example, docker run -p 80:8080 my-app will work because the port
inside the container is 8080, and docker run -p 80:81 my-app won't work because the port inside the container is 81.

### No shell

Use dev images in build stages to run shell commands and then copy any necessary artifacts into the runtime stage. In
addition, use Docker Debug to debug containers with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use docker inspect to
inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
