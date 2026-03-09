## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a SonarQube image

Start a SonarQube Community Build instance with the following command. Replace `<tag>` with the image variant you want
to run.

```bash
docker run -p 9000:9000 dhi.io/sonarqube:<tag>
```

For production deployments with persistence:

```bash
docker run -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  dhi.io/sonarqube:<tag>
```

You can then browse to `http://localhost:9000` to access the SonarQube web interface.

## Common SonarQube use cases

### Basic code analysis server

Use the following to run a single, local instance of SonarQube for development teams. Setting
`SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true` bypasses strict checks for production environments, letting SonarQube start
even if some of the recommended production settings are not met.

```bash
docker run -d \
  --name sonarqube-dev \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  dhi.io/sonarqube:<tag>
```

For development teams using Compose, the following is an example `compose.yaml`. It includes volume mounts for data
persistence.

```yaml
services:
  sonarqube:
    image: dhi.io/sonarqube:<tag>
    container_name: sonarqube-dev
    ports:
      - "9000:9000"
    environment:
      - SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_extensions:/opt/sonarqube/extensions

volumes:
  sonarqube_data:
  sonarqube_logs:
  sonarqube_extensions:
```

### Server with persistence

The following `compose.yaml` example demonstrates a production deployment with an external PostgreSQL database and
volume mounts:

```yaml
services:
  sonarqube:
    image: dhi.io/sonarqube:<tag>
    container_name: sonarqube-prod
    ports:
      - "9000:9000"
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://sonarqube-postgres:5432/sonarqube
      - SONAR_JDBC_USERNAME=sonarqube
      - SONAR_JDBC_PASSWORD=sonarpass
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_extensions:/opt/sonarqube/extensions
    depends_on:
      - postgres
    networks:
      - sonarnet

  postgres:
    image: dhi.io/postgres:<tag>
    container_name: sonarqube-postgres
    environment:
      - POSTGRES_DB=sonarqube
      - POSTGRES_USER=sonarqube
      - POSTGRES_PASSWORD=sonarpass
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - sonarnet

volumes:
  sonarqube_data:
  sonarqube_logs:
  sonarqube_extensions:
  postgres_data:

networks:
  sonarnet:
    driver: bridge
```

### CI/CD integration

Once your SonarQube server is running, you can integrate code analysis into your CI/CD pipeline using a SonarQube
scanner. The following GitHub Actions example shows how to do this with the
[SonarScanner for Gradle](https://github.com/SonarSource/sonar-scanner-gradle). It runs in a DHI Gradle image on a
GitHub-hosted runner. The overall pattern is similar if you're using other SonarQube scanners. You can also use the
[`sonarsource/sonarqube-scan-action` GitHub Action](https://github.com/SonarSource/sonarqube-scan-action).

This example assumes you have a Gradle project with the SonarQube plugin enabled and the following GitHub secrets in
your repository:

- `SONAR_HOST_URL`: The URL of your SonarQube server.
- `SONAR_TOKEN`: A user or project analysis token generated in the SonarQube UI.
- `DOCKER_USERNAME`: Your Docker Hub username.
- `DOCKER_PASSWORD`: Your Docker Hub password or access token.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run SonarQube analysis in custom DHI Gradle image
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/build" -w /build \
            dhi.io/gradle:<tag> \
            ./gradlew clean build sonar \
              -Dsonar.host.url="${{ secrets.SONAR_HOST_URL }}" \
              -Dsonar.token="${{ secrets.SONAR_TOKEN }}"
```

You can also use a Bash script inside your CI/CD pipelines to run the analysis inside a DHI Gradle container. Assuming
your environment variables are set, you can run:

```bash
# sign in to Docker Hub to pull the image
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

# run the Gradle image with the SonarQube plugin
docker run --rm -it \
  -v "$PWD":/build -w /build \
  dhi.io/gradle:<tag> \
  ./gradlew build sonar -Dsonar.host.url="$SONAR_HOST_URL" -Dsonar.token="$SONAR_TOKEN"
```

### Custom plugin deployment

To extend SonarQube with third-party plugins, you can build a custom image that includes the desired plugins. The
following is an example `Dockerfile` that adds a plugin:

```dockerfile
FROM dhi.io/sonarqube:<tag>

COPY ./plugins/my-custom-plugin.jar /opt/sonarqube/extensions/plugins/
```

You can then build and run your custom image.

Alternatively, you can mount plugins at run time:

```bash
docker run -d -p 9000:9000 \
  -v "$PWD/plugins:/opt/sonarqube/extensions/plugins" \
  dhi.io/sonarqube:<tag>
```

### Advanced configuration

For graceful shutdown, configure `stop-timeout` to allow in-progress analysis tasks to complete:

```bash
docker run --stop-timeout 3600 dhi.io/sonarqube:<tag>
```

To customize Java memory settings, set the `SONAR_JAVA_OPTS` and `SONAR_WEB_JAVAADDITIONALOPTS` environment variables.
The following is an example:

```bash
docker run -p 9000:9000 \
  -e SONAR_JAVA_OPTS="-Xmx2048m -Xms256m" \
  -e SONAR_WEB_JAVAADDITIONALOPTS="-Dmy.custom.property=value" \
  dhi.io/sonarqube:<tag>
```

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature            | Non-hardened SonarQube DOI                 | Docker Hardened SonarQube (DHI)                |
| ------------------ | ------------------------------------------ | ---------------------------------------------- |
| Base image         | Standard OpenJDK base                      | Hardened Debian base                           |
| User context       | Runs as `sonarqube` (uid 1000, gid 0)      | Runs as nonroot user (uid/gid 65532)           |
| Shell access       | Full shell available                       | Minimal shell utilities only in runtime images |
| Package management | Package manager included                   | No package manager in runtime images           |
| Security posture   | Standard security metadata                 | Ships with SBOM and VEX metadata               |
| Host requirements  | Docker host requirements for Elasticsearch | Same requirements as Non-hardened DOI          |

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

```
docker debug dhi.io/sonarqube:<tag>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/sonarqube:<tag> /dbg/bin/sh
```

## Image variants

The SonarQube DHI provides a runtime variant of the community edition.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

## Migrate to a Docker Hardened Image

Migration from the Docker Official SonarQube image to the DHI for SonarQube is seamless for most scenarios:

- Port binding: No changes needed - both images use port 9000
- Volume mounts: Use the same volume paths (`/opt/sonarqube/data`, `/opt/sonarqube/logs`, `/opt/sonarqube/extensions`)
- Environment variables: All SonarQube environment variables work identically (`SONAR_JAVA_OPTS`,
  `SONAR_WEB_JAVAADDITIONALOPTS`, etc.)
- Database configuration: External database setup remains identical
- File permissions: No volume ownership changes required - the image handles existing file permissions automatically
- Host requirements: Same Elasticsearch requirements apply to both images
- Plugin compatibility: Existing plugins in `/opt/sonarqube/extensions` work unchanged

### Migration steps

1. Stop your existing SonarQube container.

   ```bash
   docker stop your-sonarqube-container
   ```

1. Update your image reference.

   ```bash
   # Change from:
   docker run -p 9000:9000 -v sonarqube_data:/opt/sonarqube/data sonarqube:community

   # To:
   docker run -p 9000:9000 -v sonarqube_data:/opt/sonarqube/data dhi.io/sonarqube:<tag>
   ```

1. Start the hardened image.

   - All volumes, environment variables, and configuration work identically
   - No file permission changes needed
   - No database migration required

### Docker Compose migration

The following example `compose.yaml` includes comments that describe how to update an existing SonarQube Community Build
setup to use the DHI SonarQube image.

```yaml
services:
  sonarqube:
    # ONLY CHANGE: Update image reference
    image: dhi.io/sonarqube:<tag>  # Was: sonarqube:community
    ports:
      - "9000:9000"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_extensions:/opt/sonarqube/extensions
    environment:
      # All existing environment variables work identically
      SONAR_JAVA_OPTS: "-Xmx2048m -Xms256m"
      # Any other existing configuration...
```

## Troubleshoot migration

### Common issues

You may encounter the following issues when migrating to a Docker Hardened Image. The recommended solutions are
provided.

- Container fails to start: Check Docker host requirements (see the "Host Requirements" section)
- Custom plugins: Use dev variants for building custom plugins in multi-stage builds
- Log file access: External log processing tools can access files normally

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

## Host requirements

The following host requirements are required for Linux Docker hosts. SonarQube needs these for embedded Elasticsearch to
function properly.

> [!NOTE]
>
> On macOS and Windows, Docker Desktop handles these requirements automatically.

```bash
# Apply these settings on the Docker host (Linux only)
sudo sysctl -w vm.max_map_count=524288
sudo sysctl -w fs.file-max=131072

# Make settings permanent across reboots
echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=131072" | sudo tee -a /etc/sysctl.conf

# Optional: Set ulimits for the Docker daemon
ulimit -n 131072
ulimit -u 8192
```

## Community vs. commercial editions

This DHI currently supports SonarQube Community Build. If you're interested in commercial editions (Developer,
Enterprise, Data Center), contact your Docker sales representative.
