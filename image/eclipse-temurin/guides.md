## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this image

This Docker Hardened Eclipse Temurin image provides enterprise-grade OpenJDK distributions with enhanced security. The
image includes:

- Eclipse Temurin JDK/JRE: High-performance, TCK-tested Java runtime
- Multiple Java versions: Support for Java 8, 11, 17, 21, and 24
- JDK development variants and lightweight runtime variants
- FIPS compliance: Meets Federal Information Processing Standards
- STIG certification: Complies with Security Technical Implementation Guides
- Enhanced security: Zero-known CVEs with continuous security updates
- Multiple base OS options: Debian and Alpine Linux variants

Available variants include development images with basic Java compilation tools and minimal runtime images for
production deployment.

## Start an Eclipse Temurin image

Run the following command:

```
$ docker run dhi.io/eclipse-temurin:<tag>
```

To get a development container and get a shell use a JDK development tag (e.g., `17-jdk-debian13-dev`) and run:

```
$ docker run -it --entrypoint bash dhi.io/eclipse-temurin:<tag>
```

## Common Java use cases

### Simple Java application

Run a standalone Java application:

```bash
docker run --rm -v /path/to/myapp.jar:/app/myapp.jar \
  dhi.io/eclipse-temurin:<tag> \
  java -jar /app/myapp.jar
```

### Spring Boot application

This example shows how to create, build, and run a complete Spring Boot application using Docker Hardened Eclipse
Temurin images.

First create the project structure:

```console
mkdir -p src/main/java/com/example
```

Next, create the application files:

```java
// ./src/main/java/com/example/Application.java
package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class Application {

    @GetMapping("/")
    public String hello() {
        return "Hello World from Docker Hardened Eclipse Temurin!";
    }

    @GetMapping("/health")
    public String health() {
        return "Application is running successfully";
    }

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

```xml
<!-- ./pom.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>spring-boot-dhi-demo</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <mainClass>com.example.Application</mainClass>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

Create the Dockerfile:

```dockerfile
# ./Dockerfile

# Multi-stage build for Spring Boot application
FROM dhi.io/eclipse-temurin:<tag>-dev as builder
WORKDIR /build

# Install Maven (since DHI images don't include it by default)
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*

# Copy and build the application
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM dhi.io/eclipse-temurin:<tag>
WORKDIR /app

# Copy the built JAR from builder stage
COPY --from=builder /build/target/*.jar app.jar

# Switch to nonroot user for security
USER nonroot

# Expose application port
EXPOSE 8080

# Run the application
CMD ["java", "-jar", "app.jar"]
```

Build the Docker image:

```bash
docker build -t my-spring-boot-app .
```

Run the application:

```bash
docker run -d -p 8080:8080 --name spring-app my-spring-boot-app
```

Test the application:

```bash
# Test the main endpoint
curl http://localhost:8080/

# Test the health endpoint
curl http://localhost:8080/health
```

For development, you can use the development images directly:

```bash
# Start a development container with Maven installed
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  -p 8080:8080 \
  dhi.io/eclipse-temurin:<tag> \
  bash -c "apt-get update && apt-get install -y maven && mvn spring-boot:run"
```

### Multi-stage build for Java applications

```dockerfile
# Build stage
FROM dhi.io/eclipse-temurin:<tag> as builder
WORKDIR /build
COPY *.java .
RUN javac *.java && jar cfe myapp.jar MyMainClass *.class

# Runtime stage
FROM dhi.io/eclipse-temurin:<tag>
WORKDIR /app
COPY --from=builder /build/myapp.jar .
USER nonroot
EXPOSE 8080
CMD ["java", "-jar", "myapp.jar"]
```

### Development environment for Java compilation

Create and compile Java applications using the development environment. Here's a complete hello world example:

```java
// HelloWorld.java
public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello, World from Docker Hardened Eclipse Temurin!");
    }
}
```

Compile the Java application:

```bash
docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/eclipse-temurin:17-jdk-debian13-dev \
  javac HelloWorld.java
```

Run the compiled application:

```bash
docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/eclipse-temurin:<tag> \
  java HelloWorld
```

For a complete development workflow, you can also create a package and run it as a JAR:

```bash
# Create a JAR file
docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/eclipse-temurin:<tag> \
  jar cfe hello.jar HelloWorld HelloWorld.class

# Run the JAR
docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/eclipse-temurin:<tag> \
  java -jar hello.jar
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

### Available tags

- Runtime variants
  - `8`, `11.0-debian13`, `17`, `17-alpine3.22`: Basic runtime images
  - `21.0-fips`, `21.0.8.9-fips`: FIPS-compliant runtime variants
  - `23.0.2.7-debian13`, `24.0-debian13`: Version-specific runtime images
- Development variants
  - `11-jdk-dev`, `17-jdk-debian13-dev`, `21-jdk-alpine3.22-dev`: Development images with Java compilation tools
  - `8-jdk-debian13-fips-dev`, `21.0.8.9-jdk-debian13-fips-dev`: FIPS-compliant development variants
  - `23.0.2.7-jdk-dev`, `24.0.2.12-jdk-alpine3.22-dev`: Latest version development images

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run Java applications

Development variants include `jdk-dev` in the tag name and are intended for use in build stages of a multi-stage
Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile Java applications

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Runtime images don't contain package managers. Use package managers only in development variants with `jdk-dev` tags.                                                                                                                                                                                                        |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize `jdk-dev` variants for build stages and runtime variants for final deployment.                                                                                                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, runtime images don't contain a shell. Use `jdk-dev` variants in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                                 |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   Consider whether you need FIPS compliance, specific Java versions, or particular base OS variants.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   building Java applications, use a development variant with `jdk-dev` in the tag name because it has the tools needed
   to install packages and build dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use `jdk-dev` variants, your final
   runtime stage should use a minimal runtime variant.

1. **Install additional packages.**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only development variants with `jdk-dev` tags typically have package managers. You should use a multi-stage
   Dockerfile to install the packages. Install the packages in the build stage that uses a `jdk-dev` variant. Then, if
   needed, copy any necessary artifacts to the runtime stage that uses a runtime variant.

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

By default, runtime variants don't contain a shell. Use `jdk-dev` variants in build stages to run shell commands and
then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers with no
shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

### FIPS compliance considerations

When using FIPS variants (tags containing `fips`), ensure your Java application is configured to use FIPS-approved
cryptographic algorithms. Some applications may require additional configuration to work properly in FIPS mode. FIPS
variants are specifically designed for government and enterprise environments that require FIPS 140-2 compliance.
