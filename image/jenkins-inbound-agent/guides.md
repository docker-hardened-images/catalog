## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Jenkins Inbound Agent image

This Docker Hardened Jenkins Inbound Agent image includes:

- Jenkins Remoting library (agent.jar) for connecting agents to Jenkins controllers
- Eclipse Temurin JRE for running the agent
- Pre-configured agent work directory at `/home/jenkins/agent`
- Entrypoint script (`jenkins-agent`) that automatically starts the agent using environment variables
- Backward compatibility symlink (slave.jar -> agent.jar)

## Start a Jenkins Inbound Agent image

### Basic usage

The Jenkins Inbound Agent image automatically connects to a Jenkins controller using environment variables. The
entrypoint script reads configuration from environment variables and starts the agent without requiring manual
command-line arguments.

To start a Jenkins inbound agent container, run the following command:

```bash
$ docker run -d --name jenkins-inbound-agent --init \
  -e JENKINS_URL=http://jenkins-controller:8080 \
  -e JENKINS_SECRET=<secret-from-controller> \
  -e JENKINS_AGENT_NAME=agent1 \
  dhi.io/jenkins-inbound-agent:<tag>
```

This command:

- Runs the agent as a daemon (`-d`)
- Uses `--init` for proper signal handling and subprocess management
- Automatically connects to the Jenkins controller using the provided environment variables
- The entrypoint script handles starting `agent.jar` with the correct parameters

**Note:** The `JENKINS_SECRET` and `JENKINS_AGENT_NAME` values must match what is configured in your Jenkins controller.
You can find these values in the Jenkins UI when creating a new agent node.

### With work directory

Starting from Remoting 3.8, agents support work directories which provide logging by default and change JAR caching
behavior:

```bash
$ docker run -d --name jenkins-inbound-agent --init \
  -e JENKINS_URL=http://jenkins-controller:8080 \
  -e JENKINS_SECRET=<secret-from-controller> \
  -e JENKINS_AGENT_NAME=agent1 \
  -e JENKINS_AGENT_WORKDIR=/home/jenkins/agent \
  -v agent-workdir:/home/jenkins/agent \
  dhi.io/jenkins-inbound-agent:<tag>
```

### Environment variables

Jenkins Inbound Agent supports configuration through environment variables:

| Variable                | Description                                                      | Default                    | Required |
| ----------------------- | ---------------------------------------------------------------- | -------------------------- | -------- |
| `JENKINS_URL`           | URL of the Jenkins controller                                    | (empty)                    | Yes      |
| `JENKINS_SECRET`        | Secret token from the Jenkins controller                         | (empty)                    | Yes      |
| `JENKINS_AGENT_NAME`    | Name of the agent (must match controller configuration)          | (empty)                    | Yes      |
| `JENKINS_AGENT_WORKDIR` | Agent work directory path                                        | `/home/jenkins/agent`      | No       |
| `AGENT_WORKDIR`         | Agent work directory path (alternative to JENKINS_AGENT_WORKDIR) | `/home/jenkins/agent`      | No       |
| `JAVA_HOME`             | Java installation directory                                      | `/opt/java/openjdk/21-jre` | No       |
| `JAVA_OPTS`             | Additional JVM options                                           | (empty)                    | No       |
| `JENKINS_JAVA_OPTS`     | Java options specifically for the remoting process               | (empty)                    | No       |
| `REMOTING_OPTS`         | Additional CLI options to pass to agent.jar                      | (empty)                    | No       |
| `USER`                  | User running the agent                                           | `jenkins`                  | No       |
| `TZ`                    | Timezone                                                         | `Etc/UTC`                  | No       |
| `LANG`                  | Locale setting                                                   | `C.UTF-8`                  | No       |

Example with custom environment variables:

```bash
$ docker run -d --name jenkins-inbound-agent --init \
  -e JENKINS_URL=http://jenkins-controller:8080 \
  -e JENKINS_SECRET=<secret-from-controller> \
  -e JENKINS_AGENT_NAME=agent1 \
  -e JENKINS_AGENT_WORKDIR=/home/jenkins/agent \
  -e TZ=America/New_York \
  -e JAVA_OPTS="-Xmx512m -Xms256m" \
  -v agent-workdir:/home/jenkins/agent \
  dhi.io/jenkins-inbound-agent:<tag>
```

## Common Jenkins Inbound Agent use cases

### Basic inbound agent connection

Connect an inbound agent to a Jenkins controller using environment variables:

```bash
$ docker run -d --name jenkins-inbound-agent --init \
  -e JENKINS_URL=http://jenkins-controller:8080 \
  -e JENKINS_SECRET=<secret-from-controller> \
  -e JENKINS_AGENT_NAME=agent1 \
  dhi.io/jenkins-inbound-agent:<tag>
```

### Agent with persistent work directory

Use a named volume to persist the agent work directory across container restarts:

```bash
$ docker run -d --name jenkins-inbound-agent --init \
  -e JENKINS_URL=http://jenkins-controller:8080 \
  -e JENKINS_SECRET=<secret-from-controller> \
  -e JENKINS_AGENT_NAME=agent1 \
  -e JENKINS_AGENT_WORKDIR=/home/jenkins/agent \
  -v jenkins-agent-work:/home/jenkins/agent \
  dhi.io/jenkins-inbound-agent:<tag>
```

### Agent in Kubernetes

Deploy Jenkins inbound agents in Kubernetes using a Deployment. The following example shows a basic Kubernetes
deployment that automatically connects to a Jenkins controller:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-inbound-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins-inbound-agent
  template:
    metadata:
      labels:
        app: jenkins-inbound-agent
    spec:
      containers:
      - name: jenkins-inbound-agent
        image: dhi.io/jenkins-inbound-agent:<tag>
        env:
        - name: JENKINS_URL
          value: "http://jenkins-controller:8080"
        - name: JENKINS_SECRET
          valueFrom:
            secretKeyRef:
              name: jenkins-agent-secret
              key: secret
        - name: JENKINS_AGENT_NAME
          value: "k8s-agent-1"
        - name: JENKINS_AGENT_WORKDIR
          value: "/home/jenkins/agent"
        volumeMounts:
        - name: agent-work
          mountPath: /home/jenkins/agent
      volumes:
      - name: agent-work
        emptyDir: {}
```

### Agent with Docker Compose

Use Docker Compose to run a Jenkins controller with an inbound agent:

```yaml
version: '3.8'
services:
  jenkins-controller:
    image: dhi.io/jenkins:<tag>
    container_name: jenkins-controller
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins-data:/var/jenkins_home
    networks:
      - jenkins-network

  jenkins-inbound-agent:
    image: dhi.io/jenkins-inbound-agent:<tag>
    container_name: jenkins-inbound-agent
    init: true
    environment:
      - JENKINS_URL=http://jenkins-controller:8080
      - JENKINS_SECRET=<secret-from-controller>
      - JENKINS_AGENT_NAME=agent1
      - JENKINS_AGENT_WORKDIR=/home/jenkins/agent
    volumes:
      - agent-work:/home/jenkins/agent
    depends_on:
      - jenkins-controller
    networks:
      - jenkins-network

volumes:
  jenkins-data:
  agent-work:

networks:
  jenkins-network:
```

### Agent with custom Java options

Configure JVM options for the agent:

```bash
$ docker run -d --name jenkins-inbound-agent --init \
  -e JENKINS_URL=http://jenkins-controller:8080 \
  -e JENKINS_SECRET=<secret-from-controller> \
  -e JENKINS_AGENT_NAME=agent1 \
  -e JAVA_OPTS="-Xmx1024m -Xms512m" \
  dhi.io/jenkins-inbound-agent:<tag>
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
