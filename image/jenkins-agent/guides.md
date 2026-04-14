## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/jenkins-agent:<tag>`
- Mirrored image: `<your-namespace>/dhi-jenkins-agent:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this jenkins-agent image

This Docker Hardened jenkins-agent image includes the Jenkins Agent component in a single, security-hardened package:

- **Jenkins Remoting library** (`agent.jar`): Connects Jenkins agents to Jenkins controllers, located at
  `/usr/share/jenkins/agent.jar` (Remoting version `3345`)
- **Backward compatibility symlink**: `slave.jar → agent.jar` at `/usr/share/jenkins/slave.jar`
- **Eclipse Temurin JRE 21**: Java runtime at `/usr/local/bin/java` (`openjdk 21.0.10`, Temurin-21.0.10+7)
- **Bash shell**: Included in the runtime image (required for running build jobs)
- **Pre-configured work directory**: `/home/jenkins/agent`
- **TLS support**: Standard TLS certificates included for secure communication

> **Note:** Unlike most Docker Hardened Images, the jenkins-agent runtime image **includes bash**. This is intentional —
> Jenkins build jobs require a shell to execute pipeline steps.

## Start a jenkins-agent container

The jenkins-agent image is designed to connect to a Jenkins controller. The default CMD runs
`/usr/local/bin/java -jar /usr/share/jenkins/agent.jar` automatically, so you can start the container without specifying
a command.

```bash
docker run -i --rm --name jenkins-agent --init \
  dhi.io/jenkins-agent:<tag>
```

This command:

- Runs the agent in interactive mode (`-i`) — required for the remoting protocol
- Removes the container when it exits (`--rm`)
- Uses `--init` for proper signal handling
- Executes the default CMD to connect to a Jenkins controller

**Expected behavior:** Without a Jenkins controller connected, the agent outputs the remoting capacity handshake string
and waits for input on stdin:

```
<===[JENKINS REMOTING CAPACITY]===>rO0ABXNyABpodWRzb24...
```

This is expected — the agent JAR is working correctly but waiting for a controller connection. This is not an error.

### With work directory

Starting from Remoting 3.8, agents support work directories which provide logging by default and change JAR caching
behavior:

```bash
docker run -i --rm --name jenkins-agent --init \
  -v agent-workdir:/home/jenkins/agent \
  dhi.io/jenkins-agent:<tag> \
  /usr/local/bin/java -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

Expected output:

```
INFO: Using /home/jenkins/agent/remoting as a remoting work directory
INFO: Both error and output logs will be printed to /home/jenkins/agent/remoting
<===[JENKINS REMOTING CAPACITY]===>rO0ABXNyABpodWRzb24...
```

## Environment variables

| Variable        | Description                 | Default                    |
| --------------- | --------------------------- | -------------------------- |
| `AGENT_WORKDIR` | Agent work directory path   | `/home/jenkins/agent`      |
| `JAVA_HOME`     | Java installation directory | `/opt/java/openjdk/21-jre` |
| `JAVA_VERSION`  | Java version                | `jre-21.0.10+7`            |
| `LANG`          | Locale setting              | `en_US.UTF-8`              |
| `TZ`            | Timezone                    | `Etc/UTC`                  |
| `USER`          | User running the agent      | `jenkins`                  |

Example with custom environment variables:

```bash
docker run -i --rm --name jenkins-agent --init \
  -e TZ=America/New_York \
  -e AGENT_WORKDIR=/home/jenkins/agent \
  dhi.io/jenkins-agent:<tag> \
  /usr/local/bin/java -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

## Common jenkins-agent use cases

### Basic agent connection

Connect an agent to a Jenkins controller using the URL, secret, and agent name provided by the controller:

```bash
docker run -i --rm --name jenkins-agent --init \
  dhi.io/jenkins-agent:<tag> \
  /usr/local/bin/java -jar /usr/share/jenkins/agent.jar \
  -url http://jenkins-controller:8080 \
  -workDir /home/jenkins/agent \
  -secret <secret> \
  -name <agent-name>
```

### Agent with persistent work directory

Use a named volume to persist the agent work directory across container restarts:

```bash
docker run -i --rm --name jenkins-agent --init \
  -v jenkins-agent-work:/home/jenkins/agent \
  dhi.io/jenkins-agent:<tag> \
  /usr/local/bin/java -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

### Agent in Kubernetes

Deploy Jenkins agents in Kubernetes using a Deployment:

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
        command: ["/usr/local/bin/java", "-jar", "/usr/share/jenkins/agent.jar"]
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
docker run -i --rm --name jenkins-agent --init \
  dhi.io/jenkins-agent:<tag> \
  /usr/local/bin/java -Xmx512m -Xms256m \
  -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

## Official images vs Docker Hardened Images

| Feature             | DOI (`docker.io/jenkins/agent`) | DHI (`dhi.io/jenkins-agent`)                                    |
| ------------------- | ------------------------------- | --------------------------------------------------------------- |
| User                | `jenkins`                       | `jenkins`                                                       |
| Shell               | bash (included)                 | bash (included)                                                 |
| Package manager     | Included                        | No (runtime) / APT (dev)                                        |
| Default CMD         | `["bash"]`                      | `["/usr/local/bin/java","-jar","/usr/share/jenkins/agent.jar"]` |
| Entrypoint          | None                            | None                                                            |
| Java version        | OpenJDK 21 (Temurin)            | OpenJDK 21.0.10 (Temurin-21.0.10+7)                             |
| `JAVA_HOME`         | `/opt/java/openjdk`             | `/opt/java/openjdk/21-jre`                                      |
| `LANG`              | `C.UTF-8`                       | `en_US.UTF-8`                                                   |
| Remoting version    | 3307                            | 3345 (newer)                                                    |
| Zero CVE commitment | No                              | Yes                                                             |
| FIPS variant        | No                              | Yes (subscription required)                                     |
| Base OS             | Debian                          | Docker Hardened Images (Debian 13)                              |
| Signed provenance   | No                              | Yes                                                             |
| SBOM / VEX metadata | No                              | Yes                                                             |
| Compliance labels   | None                            | CIS (runtime)                                                   |
| Architectures       | amd64, arm64                    | amd64, arm64                                                    |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- **Runtime variants** are designed to run the Jenkins agent in production. These images:

  - Run as the `jenkins` user
  - Include bash (required for build job execution)
  - Do not include a package manager
  - Contain only the minimal set of libraries needed to run the agent

- **Build-time variants** typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager (apt-get 3.0.3)
  - Are used to build or compile applications

- **FIPS variants** include `fips` in the variant name and tag. They use cryptographic modules validated under FIPS 140,
  a U.S. government standard for secure cryptographic operations. Pulling FIPS variants requires a Docker subscription —
  the tags return 401 without one.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, update your Dockerfile or Kubernetes manifests. Common changes
are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                    |
| :----------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile or Kubernetes manifests with a Docker Hardened Image.                                                                 |
| Package management | Runtime images don't contain package managers. Use images with a `dev` tag for build stages that require package installation.                                    |
| User               | Both DOI and DHI run as the `jenkins` user. No changes required.                                                                                                  |
| Shell              | The runtime image includes bash. No changes required for build jobs that rely on a shell.                                                                         |
| Default CMD        | DOI defaults to `["bash"]`. DHI defaults to `["/usr/local/bin/java","-jar","/usr/share/jenkins/agent.jar"]`. Update any scripts that rely on the DOI default CMD. |
| Java path          | DOI `JAVA_HOME=/opt/java/openjdk`. DHI `JAVA_HOME=/opt/java/openjdk/21-jre`. Update any scripts that reference `JAVA_HOME` directly.                              |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                |
| Ports              | Jenkins agents do not bind to any ports — they make outbound connections to the controller only. Privileged port restrictions do not apply.                       |
| agent.jar path     | Both DOI and DHI use `/usr/share/jenkins/agent.jar`. No changes required.                                                                                         |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and runtime images for production.                                                                               |

The following steps outline the general migration process.

1. **Find hardened images for your app.** Inspect the image tags for `dhi.io/jenkins-agent` and find the variant that
   meets your needs (runtime, dev, or FIPS).

1. **Update the image reference in your Kubernetes manifests or Dockerfile.**

   ```yaml
   # In your Deployment manifest
   containers:
     - name: jenkins-agent
       image: dhi.io/jenkins-agent:<tag>
   ```

1. **Update the default CMD if needed.** The DHI default CMD runs the agent jar directly. If your existing setup
   overrides the CMD, verify the java path is `/usr/local/bin/java`.

1. **Verify the agent connects to the controller.** After migration, confirm the agent appears as online in the Jenkins
   controller UI.

## Troubleshoot migration

### General debugging

Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to a running container for debugging:

```bash
docker debug <container-name>
```

### Permissions

The runtime image runs as the `jenkins` user. Ensure that mounted volumes and files are accessible to the `jenkins`
user. You may need to set appropriate permissions on host directories before mounting them.

### Deprecated positional arguments

Passing the secret and agent name as positional arguments is deprecated and produces a warning:

```
WARNING: Providing the secret and agent name as positional arguments is deprecated;
use "-secret" and "-name" instead.
```

Always use the `-secret` and `-name` flags explicitly:

```bash
/usr/local/bin/java -jar /usr/share/jenkins/agent.jar \
  -url http://jenkins-controller:8080 \
  -secret <secret> \
  -name <agent-name>
```

### Default CMD difference

The DOI default CMD is `["bash"]` while the DHI default CMD is
`["/usr/local/bin/java","-jar","/usr/share/jenkins/agent.jar"]`. If your setup relies on the DOI default, update your
`command` or `args` fields in Kubernetes manifests or your `docker run` command accordingly.

### Java path

The DHI `JAVA_HOME` is `/opt/java/openjdk/21-jre` while the DOI `JAVA_HOME` is `/opt/java/openjdk`. Update any scripts
or environment variables that reference `JAVA_HOME` directly.

### No package manager

The runtime image does not include a package manager. If your build jobs require additional tools, use the `dev` image
variant as a build stage and copy the required binaries to the runtime stage.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
