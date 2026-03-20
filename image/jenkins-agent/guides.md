## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Jenkins Agent image

This Docker Hardened Jenkins Agent image includes:

- Jenkins Remoting library (agent.jar) for connecting agents to Jenkins controllers
- Eclipse Temurin JRE for running the agent
- Pre-configured agent work directory at `/home/jenkins/agent`
- Backward compatibility symlink (slave.jar -> agent.jar)

## Start a Jenkins Agent image

### Basic usage

The Jenkins Agent image is designed to connect to a Jenkins controller. The default command runs
`java -jar /usr/share/jenkins/agent.jar`, so you can start the container without specifying a command. The agent
requires connection parameters from the controller.

To start a Jenkins agent container, run the following command:

```bash
$ docker run -i --rm --name jenkins-agent --init \
  dhi.io/jenkins-agent:<tag>
```

This command:

- Runs the agent in interactive mode (`-i`)
- Removes the container when it exits (`--rm`)
- Uses `--init` for proper signal handling
- Executes the agent.jar (default cmd) to connect to a Jenkins controller

**Note:** This image does not include a shell. If you need to override the default command or run custom commands, you
can specify them:

```bash
$ docker run -i --rm --name jenkins-agent --init \
  dhi.io/jenkins-agent:<tag> \
  java -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

**Note:** The agent requires connection parameters (controller URL, credentials, etc.) which are typically provided by
the Jenkins controller when launching agents via the "Launch agent via execution of command on the controller" method.

**Expected behavior:** If you run this command without a Jenkins controller connected, you will see an `EOFException`
error. This is expected and indicates that the agent JAR is working correctly but cannot establish a connection. The
agent must be launched by a Jenkins controller or provided with connection parameters via command-line arguments or
environment variables. This behavior matches the upstream `jenkins/agent` image and is not a Docker Hardened
Images-specific issue.

### With work directory

Starting from Remoting 3.8, agents support work directories which provide logging by default and change JAR caching
behavior. Override the default command to specify the work directory:

```bash
$ docker run -i --rm --name jenkins-agent --init \
  -v agent-workdir:/home/jenkins/agent \
  dhi.io/jenkins-agent:<tag> \
  java -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

### Environment variables

Jenkins Agent supports configuration through environment variables:

| Variable        | Description                 | Default                    | Required |
| --------------- | --------------------------- | -------------------------- | -------- |
| `AGENT_WORKDIR` | Agent work directory path   | `/home/jenkins/agent`      | No       |
| `JAVA_HOME`     | Java installation directory | `/opt/java/openjdk/21-jre` | No       |
| `USER`          | User running the agent      | `jenkins`                  | No       |
| `TZ`            | Timezone                    | `Etc/UTC`                  | No       |
| `LANG`          | Locale setting              | `C.UTF-8`                  | No       |

Example with custom environment variables:

```bash
$ docker run -i --rm --name jenkins-agent --init \
  -e TZ=America/New_York \
  -e AGENT_WORKDIR=/home/jenkins/agent \
  dhi.io/jenkins-agent:<tag> \
  java -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

## Common Jenkins Agent use cases

### Basic agent connection

Connect an agent to a Jenkins controller using the launch method configured on the controller:

```bash
$ docker run -i --rm --name jenkins-agent --init \
  dhi.io/jenkins-agent:<tag> \
  java -jar /usr/share/jenkins/agent.jar \
  -url http://jenkins-controller:8080 \
  -workDir /home/jenkins/agent \
  <secret> \
  <agent-name>
```

### Agent with persistent work directory

Use a named volume to persist the agent work directory across container restarts:

```bash
$ docker run -i --rm --name jenkins-agent --init \
  -v jenkins-agent-work:/home/jenkins/agent \
  dhi.io/jenkins-agent:<tag> \
  java -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

### Agent in Kubernetes

Deploy Jenkins agents in Kubernetes using a Deployment or StatefulSet. The following example shows a basic Kubernetes
deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins-agent
  template:
    metadata:
      labels:
        app: jenkins-agent
    spec:
      containers:
      - name: jenkins-agent
        image: dhi.io/jenkins-agent:<tag>
        command: ["java", "-jar", "/usr/share/jenkins/agent.jar"]
        args: ["-workDir", "/home/jenkins/agent"]
        volumeMounts:
        - name: agent-work
          mountPath: /home/jenkins/agent
        env:
        - name: AGENT_WORKDIR
          value: "/home/jenkins/agent"
      volumes:
      - name: agent-work
        emptyDir: {}
```

### Agent with custom Java options

Configure JVM options for the agent:

```bash
$ docker run -i --rm --name jenkins-agent --init \
  -e JAVA_OPTS="-Xmx512m -Xms256m" \
  dhi.io/jenkins-agent:<tag> \
  java $JAVA_OPTS -jar /usr/share/jenkins/agent.jar
```

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
