## Prerequisites

- Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
  organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
  repository**, and then follow the on-screen instructions.
- To use the code snippets in this guide, replace `<your-namespace>` with your organization's namespace and `<tag>` with
  the image variant you want to run.

## What's included in this Azul Platform Prime image

This Docker Hardened Azul Platform Prime image includes a complete, high-performance Java development and runtime
environment powered by Azul Zing JVM in a single, security-hardened package:

- **Azul Zing JVM**: Enterprise-grade Java Virtual Machine with advanced performance optimizations
- **C4 Pauseless Garbage Collector**: Azul's revolutionary garbage collector that eliminates GC pauses
- **Falcon JIT Compiler**: Advanced Just-In-Time compiler for optimized code execution
- **Complete JDK tools**: Full suite of JDK binaries including:
  - Runtime: `java` for running applications
  - Compiler: `javac` for compiling Java source code
  - Archiver: `jar` for creating JAR files
  - Monitoring: `jps`, `jstat`, and other diagnostic tools
- **TLS certificates**: Pre-installed CA certificates for secure connections
- **Locale support**: UTF-8 locale configuration (en_US.UTF-8)
- **Performance enhancements**: Cloud-optimized settings for reduced latency and consistent performance

Unlike standard JDKs, Azul Zing delivers:

- Predictable performance under heavy loads
- Reduced cloud infrastructure costs through better resource utilization
- Enterprise-grade support and security patches
- Production-proven stability from thousands of deployments

Note: While this image includes full JDK capabilities, it maintains security hardening by excluding shell access and
system utilities.

## Start an Azul Platform Prime instance

Run the following command to display the Java help information. Replace `<your-namespace>` with your organization's
namespace and `<tag>` with the image variant you want to run.

```bash
docker run --rm <your-namespace>/dhi-azul:<tag>
```

To check the Java version:

```bash
docker run --rm <your-namespace>/dhi-azul:<tag> java -version
```

## Common Azul Platform Prime use cases

### Run a Java application

Run your compiled Java application directly from the container. Mount your local JAR file and run it:

```bash
docker run -v $(pwd):/app <your-namespace>/dhi-azul:<tag> java -jar /app/myapp.jar
```

### Compile and run Java code

Since the image includes `javac`, you can compile and run Java applications directly:

Create a Java file:

```bash
echo 'public class Hello { public static void main(String[] args) { System.out.println("Hello from Azul Zing!"); } }' > Hello.java
```

Compile and run:

```bash
# Compile the Java file
docker run -v $(pwd):/app -w /app <your-namespace>/dhi-azul:<tag> javac Hello.java

# Run the compiled class
docker run -v $(pwd):/app -w /app <your-namespace>/dhi-azul:<tag> java Hello
```

### Create and run a JAR file

Build a JAR file using the included `jar` tool:

```bash
# Create a manifest file
echo "Main-Class: Hello" > Manifest.txt

# Create the JAR
docker run -v $(pwd):/app -w /app <your-namespace>/dhi-azul:<tag> jar cvfm hello.jar Manifest.txt Hello.class

# Run the JAR
docker run -v $(pwd):/app -w /app <your-namespace>/dhi-azul:<tag> java -jar hello.jar
```

### Multi-stage build for production

Note: Since the image has no shell, RUN commands won't work. Compile your code outside the container or use a different
build image:

```docker
# Option 1: Use a different image for building
FROM openjdk:23 AS builder
WORKDIR /app
COPY *.java .
RUN javac *.java
RUN jar cvf app.jar *.class

# Runtime stage with DHI
FROM <your-namespace>/dhi-azul:23-jdk-prime
WORKDIR /app
COPY --from=builder /app/app.jar .
CMD ["java", "-cp", "app.jar", "Main"]
```

Alternatively, compile locally and copy only the JAR:

```docker
FROM <your-namespace>/dhi-azul:23-jdk-prime
WORKDIR /app
COPY app.jar .
CMD ["java", "-jar", "app.jar"]
```

### Optimize for low-latency applications

Azul Zing comes with the C4 garbage collector enabled by default for pauseless operation. You can tune memory settings:

```bash
# Run with specific heap size
docker run -v $(pwd):/app <your-namespace>/dhi-azul:<tag> \
  java -Xmx512m -Xms512m \
  -jar /app/myapp.jar
```

### Monitor JVM performance

Use built-in monitoring tools to track application performance:

```bash
# Start your application
docker run -d --name my-app -v $(pwd):/app <your-namespace>/dhi-azul:<tag> java -jar /app/myapp.jar

# List Java processes (note: limited without shell, but jps works)
docker exec my-app jps

# Clean up
docker stop my-app && docker rm my-app
```

## Docker Official Images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official Azul/OpenJDK        | Docker Hardened Azul Platform Prime          |
| --------------- | ----------------------------------- | -------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches |
| Shell access    | Full shell (bash/sh) available      | No shell                                     |
| Package manager | apt/apk available                   | No package manager                           |
| User            | Runs as root by default             | Runs as nonroot user                         |
| Attack surface  | Larger due to additional utilities  | Minimal, only Java tools                     |
| Debugging       | Traditional shell debugging         | Use Docker Debug for troubleshooting         |
| Base OS         | Various Alpine/Debian versions      | Hardened Debian 13 base                      |
| JVM             | Standard OpenJDK or Azul Zulu       | Azul Zing with C4 GC                         |
| JDK Tools       | Varies by image                     | Full JDK included (javac, jar, etc.)         |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

While the image includes full JDK capabilities for Java development and runtime needs, it intentionally excludes system
utilities and shell access to maintain security hardening.

The hardened images don't contain a shell nor system tools for debugging. Common debugging methods for applications
built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- JVM diagnostic tools included in the image (jps, jstat, etc.)
- Application logging and monitoring

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
docker debug <container-name>
```

## Image variants

The Azul Platform Prime Docker Hardened Images are available as runtime images that include full JDK capabilities:

- **Available versions**: 11, 17, 21, and 23
- **Base OS**: Debian 13
- **User**: Runs as nonroot (UID 65532)
- **Included tools**: Full JDK (java, javac, jar, and diagnostic tools)
- **Not included**: Shell, package managers, system utilities

These images are designed to run your application in production while still providing the ability to compile and package
Java code when needed. They are intended to be used either directly or as the `FROM` image in a Dockerfile.

Note: No separate dev variants are available as the runtime images include the full JDK toolchain.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                            |
| Package management | Images don't contain package managers. Install dependencies using multi-stage builds with other images if needed.                                                                                                                    |
| Non-root user      | Images run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                      |
| Multi-stage build  | Can use the same image for both build and runtime stages since full JDK is included, or optimize with multi-stage builds.                                                                                                            |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                   |
| Ports              | Images run as a nonroot user by default. Applications can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure your Java application to use ports above 1024. |
| Entry point        | Default command is `java --help`. Override with your application's entry point.                                                                                                                                                      |
| No shell           | Images don't contain a shell. Cannot use shell scripts or commands that require shell interpretation.                                                                                                                                |
| JAVA_HOME          | The JAVA_HOME environment variable is set to `/opt/zing/zing-jdk${MAJOR_VERSION}`. Adjust your scripts if they rely on a different path.                                                                                             |
| JVM Type           | These images use Azul Zing JVM, not standard OpenJDK. Review any JVM-specific flags or configurations.                                                                                                                               |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   Azul Platform Prime images are available in versions 11, 17, 21, and 23. Choose the version that matches your
   application's requirements.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image:

   ```docker
   FROM <your-namespace>/dhi-azul:23-jdk-prime
   ```

1. **Adjust for no shell.**

   Since there's no shell, you cannot use shell scripts or commands that require shell interpretation. Use Java directly
   or compile commands into your application.

1. **Handle file permissions.**

   The image runs as nonroot user. Ensure files are accessible:

   ```docker
   COPY --chown=65532:65532 app.jar /app/app.jar
   ```

1. **Configure ports.**

   Use ports above 1024:

   ```docker
   EXPOSE 8080
   ```

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images don't contain a shell nor system tools for debugging. The recommended method for debugging is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers. Docker Debug provides a
shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists during
the debugging session.

You can also use the included JVM diagnostic tools:

```bash
docker exec <container> jps
docker exec <container> jstat -gc <pid>
```

### Permissions

Images run as the nonroot user (UID 65532). Ensure that necessary files and directories are accessible to the nonroot
user. You may need to copy files to different directories or change permissions so your application can access them.

### Privileged ports

Non-root users can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older
than 20.10. Configure your Java applications to listen on ports 8080, 8443, or other ports above 1024.

### No shell

Images don't contain a shell. You cannot:

- Run shell scripts
- Use shell redirection or pipes
- Execute commands that require shell interpretation

Instead, run Java commands directly or build functionality into your application.

### Entry point

The default command is `java --help`. Always specify your application's entry point:

```docker
CMD ["java", "-jar", "/app/myapp.jar"]
```

### Azul Zing-specific considerations

#### Performance tuning

Azul Zing comes pre-configured with optimized settings. Key considerations:

- **C4 Garbage Collector**: Enabled by default for pauseless operation
- **Memory settings**: Zing may use different default heap sizes. Monitor and adjust `-Xmx` and `-Xms` as needed
- **Falcon JIT**: Enabled by default for optimized compilation

#### JNI compatibility

Applications using Java Native Interface (JNI) should be thoroughly tested with the Debian 13 base and Zing JVM. Ensure:

1. Native libraries are compatible with Debian 13 and glibc
1. Required native dependencies are present
1. Library paths are correctly configured

#### Monitoring and profiling

Azul Zing includes enhanced monitoring capabilities:

```bash
# Enable detailed GC logging (note: no shell redirection available)
docker run <your-namespace>/dhi-azul:<tag> \
  java -Xlog:gc* \
  -jar /app/myapp.jar

# Use JVM diagnostic tools
docker exec <container> jps -l
docker exec <container> jstat -gc <pid> 1000
```
