## Prerequisites

- Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
  organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
  repository**, and then follow the on-screen instructions.
- To use the code snippets in this guide, replace `<your-namespace>` with your organization's namespace and `<tag>` with
  the image variant you want to run.

## What's included in this Jenkins image

This Docker Hardened Jenkins image includes:

- Jenkins automation server with plugin support for CI/CD workflows
- Eclipse Temurin JRE for running Jenkins
- tini as the init process for proper signal handling
- Pre-configured agent communication on port 50000
- Common utilities (bash, git, gnupg, openssh-client) for Jenkins operations

## Start a Jenkins image

### Basic usage

To start a Jenkins container, run the following command:

```bash
$ docker run -d --name jenkins-server -p 8080:8080 -p 50000:50000 \
  -v jenkins-data:/var/jenkins_home \
  <your-namespace>/dhi-jenkins:<tag>
```

This command:

- Runs Jenkins in detached mode (`-d`)
- Exposes the web UI on port 8080
- Exposes the agent communication port on 50000
- Mounts a named volume `jenkins-data` to persist Jenkins configuration and build data

### With Docker Compose (recommended for complex setups)

Create a `compose.yml` file with the following content:

```yaml
version: '3.8'
services:
  jenkins:
    image: <your-namespace>/dhi-jenkins:<tag>
    container_name: jenkins-server
    ports:
      - "8080:8080"
      - "50000:50000"
    environment:
      - JENKINS_OPTS=-Djenkins.install.runSetupWizard=false
      - JENKINS_ADMIN_ID=admin
      - JENKINS_ADMIN_PASSWORD=changeme
    volumes:
      - jenkins-data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    restart: on-failure

volumes:
  jenkins-data:
    driver: local
```

Then start the services:

```bash
$ docker compose up -d
```

### Environment variables

Jenkins supports configuration through environment variables and system properties:

| Variable                   | Description                                 | Default                                   | Required |
| -------------------------- | ------------------------------------------- | ----------------------------------------- | -------- |
| `JENKINS_HOME`             | Jenkins data directory inside container     | `/var/jenkins_home`                       | No       |
| `JENKINS_SLAVE_AGENT_PORT` | Port for agent communication                | `50000`                                   | No       |
| `JAVA_HOME`                | Java installation directory                 | `/opt/java/openjdk`                       | No       |
| `JENKINS_UC`               | Jenkins updates center URL                  | `https://updates.jenkins.io`              | No       |
| `JENKINS_UC_EXPERIMENTAL`  | Experimental updates center URL             | `https://updates.jenkins.io/experimental` | No       |
| `JENKINS_OPTS`             | Additional Java options for Jenkins startup | (empty)                                   | No       |
| `JENKINS_VERSION`          | Version of Jenkins (informational only)     | See image tag                             | No       |
| `JAVA_OPTS`                | Additional JVM options                      | (empty)                                   | No       |

Example with custom environment variables:

```bash
$ docker run -d --name jenkins-custom -p 8080:8080 \
  -e JAVA_OPTS="-Xmx512m -Xms512m" \
  -v jenkins-data:/var/jenkins_home \
  <your-namespace>/dhi-jenkins:<tag>
```

## Common Jenkins use cases

### Basic Jenkins setup with local builds

This is the simplest Jenkins setup for small projects or testing:

```bash
$ docker run -d --name jenkins-basic -p 8080:8080 -p 50000:50000 \
  -v jenkins-data:/var/jenkins_home \
  <your-namespace>/dhi-jenkins:<tag>
```

Access Jenkins at `http://localhost:8080`. On first run, retrieve the initial admin password:

```bash
$ docker exec jenkins-basic cat /var/jenkins_home/secrets/initialAdminPassword
```

### Jenkins with persistent storage and data backup

Store Jenkins data on the host filesystem for easier backups and recovery:

```yaml
version: '3.8'
services:
  jenkins:
    image: <your-namespace>/dhi-jenkins:<tag>
    container_name: jenkins-persistent
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - ./jenkins-home:/var/jenkins_home
      - ./backups:/var/backups
    environment:
      - JAVA_OPTS=-Xmx1024m
    restart: on-failure
```

Backup Jenkins data:

```bash
$ docker compose exec jenkins tar -czf /var/backups/jenkins-backup-$(date +%Y%m%d).tar.gz -C /var/jenkins_home .
```

### Jenkins with Docker-in-Docker for containerized builds

This setup allows Jenkins agents to build Docker images:

```yaml
version: '3.8'
services:
  jenkins:
    image: <your-namespace>/dhi-jenkins:<tag>
    container_name: jenkins-dind
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins-data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JAVA_OPTS=-Xmx2048m
    restart: on-failure
    networks:
      - jenkins-net

  docker-dind:
    image: docker:dind
    container_name: jenkins-docker
    privileged: true
    environment:
      - DOCKER_TLS_CERTDIR=/certs
    volumes:
      - jenkins-docker-certs:/certs/client
      - jenkins-data:/var/jenkins_home
    networks:
      - jenkins-net

volumes:
  jenkins-data:
  jenkins-docker-certs:

networks:
  jenkins-net:
```

### Jenkins with custom plugins and configuration

Pre-install plugins and configure Jenkins without the setup wizard:

```dockerfile
FROM <your-namespace>/dhi-jenkins:latest

USER jenkins

# Install plugins using jenkins-plugin-cli
RUN jenkins-plugin-cli --plugins \
  git \
  github \
  pipeline-model-definition \
  docker-workflow \
  junit

# Copy custom configuration files
COPY --chown=jenkins:jenkins config/jenkins.yaml /usr/share/jenkins/ref/jenkins.yaml
COPY --chown=jenkins:jenkins config/scriptApproval.xml /usr/share/jenkins/ref/scriptApproval.xml
```

Build and run:

```bash
$ docker build -t my-jenkins:custom .
$ docker run -d --name jenkins-custom -p 8080:8080 \
  -v jenkins-data:/var/jenkins_home \
  my-jenkins:custom
```

### Jenkins with multiple agents for distributed builds

Run Jenkins with multiple build agents for better scalability:

```yaml
version: '3.8'
services:
  jenkins-master:
    image: <your-namespace>/dhi-jenkins:<tag>
    container_name: jenkins-master
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins-master-data:/var/jenkins_home
    environment:
      - JAVA_OPTS=-Xmx2048m
    restart: on-failure
    networks:
      - jenkins-network

  jenkins-agent-1:
    image: <your-namespace>/dhi-jenkins:<tag>
    container_name: jenkins-agent-1
    environment:
      - JENKINS_URL=http://jenkins-master:8080/
      - JENKINS_AGENT_NAME=agent-1
      - JENKINS_SECRET=<secret-from-jenkins-ui>
      - JENKINS_AGENT_WORKDIR=/home/jenkins/agent
    volumes:
      - jenkins-agent-1-data:/home/jenkins/agent
    depends_on:
      - jenkins-master
    restart: on-failure
    networks:
      - jenkins-network
    command: java -jar /usr/share/jenkins/agent.jar

  jenkins-agent-2:
    image: <your-namespace>/dhi-jenkins:<tag>
    container_name: jenkins-agent-2
    environment:
      - JENKINS_URL=http://jenkins-master:8080/
      - JENKINS_AGENT_NAME=agent-2
      - JENKINS_SECRET=<secret-from-jenkins-ui>
      - JENKINS_AGENT_WORKDIR=/home/jenkins/agent
    volumes:
      - jenkins-agent-2-data:/home/jenkins/agent
    depends_on:
      - jenkins-master
    restart: on-failure
    networks:
      - jenkins-network
    command: java -jar /usr/share/jenkins/agent.jar

volumes:
  jenkins-master-data:
  jenkins-agent-1-data:
  jenkins-agent-2-data:

networks:
  jenkins-network:
```

## Initial setup and configuration

### Accessing Jenkins for the first time

After starting Jenkins, access the web interface:

1. Open your browser and navigate to `http://localhost:8080`
1. Retrieve the initial admin password:
   ```bash
   $ docker exec <container-name> cat /var/jenkins_home/secrets/initialAdminPassword
   ```
1. Enter the password on the unlock page
1. Follow the setup wizard to install recommended plugins and create an admin user

## Troubleshooting

### Jenkins not responding after startup

If Jenkins doesn't respond, check the logs:

```bash
$ docker logs jenkins-server
```

Common issues:

- Insufficient memory: Increase JVM memory with `JAVA_OPTS=-Xmx1024m`
- Port conflicts: Ensure ports 8080 and 50000 are available
- Disk space: Jenkins needs sufficient disk space; check with `docker exec jenkins-server df -h /var/jenkins_home`

### Plugins not loading or build failures

Check plugin compatibility and Jenkins logs:

```bash
$ docker exec jenkins-server tail -f /var/jenkins_home/jenkins.log
```

### Resetting Jenkins

To reset Jenkins to initial state (caution: removes all data):

```bash
$ docker stop jenkins-server
$ docker rm jenkins-server
$ docker volume rm jenkins-data
$ docker run -d --name jenkins-server -p 8080:8080 \
  -v jenkins-data:/var/jenkins_home \
  <your-namespace>/dhi-jenkins:<tag>
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
