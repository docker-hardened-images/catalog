## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start Cassandra Reaper with the default in-memory backend

The image ships with an in-memory storage backend by default, which is suitable for development or one-off repair
orchestration that does not need to survive restarts.

```
docker run --rm -p 8080:8080 -p 8081:8081 dhi.io/cassandra-reaper:4
```

Open `http://localhost:8080/webui/` to access the web UI, or query the REST API on port 8080. The Dropwizard admin port
is available on 8081 (`http://localhost:8081/healthcheck`).

### Use a persistent storage backend

For production deployments, bind-mount your own configuration file over `/etc/cassandra-reaper/cassandra-reaper.yaml` to
switch to a Cassandra or PostgreSQL backend. The image includes starter templates at
`/etc/cassandra-reaper/cassandra-reaper-cassandra.yaml` and `/etc/cassandra-reaper/cassandra-reaper-memory.yaml` for
reference; copy the one that matches your backend, edit the contact points / JDBC URL / credentials to match your
environment, and mount it back in:

```
docker run --rm -p 8080:8080 -p 8081:8081 \
  -v $(pwd)/my-reaper.yaml:/etc/cassandra-reaper/cassandra-reaper.yaml:ro \
  dhi.io/cassandra-reaper:4
```

See the upstream [Configuration Reference](http://cassandra-reaper.io/docs/configuration/) for the full list of
supported keys. Unlike the upstream image, the hardened image does not read `REAPER_STORAGE_TYPE`, `REAPER_CASS_*`, or
`REAPER_DB_*` environment variables — these are expressed directly in the configuration file.

### Configure authentication

Reaper 4.x uses Dropwizard's built-in access control with JWT session tokens. Admin and read-only credentials are the
only settings sourced from environment variables in the hardened image: `REAPER_AUTH_USER`, `REAPER_AUTH_PASSWORD`,
`REAPER_READ_USER`, and `REAPER_READ_USER_PASSWORD` (all empty by default — set them to enable authentication).

```
docker run --rm -p 8080:8080 -p 8081:8081 \
  -e REAPER_AUTH_USER=admin \
  -e REAPER_AUTH_PASSWORD=change-me \
  dhi.io/cassandra-reaper:4
```

### Tuning the JVM

The hardened image invokes `java -jar` directly; there is no wrapper script reading `JAVA_OPTS`. Pass JVM flags via
`JAVA_TOOL_OPTIONS`, which the Java runtime picks up automatically:

```
docker run --rm -p 8080:8080 -p 8081:8081 \
  -e REAPER_STORAGE_TYPE=memory \
  -e JAVA_TOOL_OPTIONS="-XX:+UseG1GC -XX:MaxGCPauseMillis=500 -Xms1g -Xmx1g" \
  dhi.io/cassandra-reaper:4
```

## Differences from upstream `thelastpickle/cassandra-reaper`

| Aspect                        | Upstream                                                                                                                                                      | Docker Hardened Image                                                                                                                                                                                                                               |
| :---------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base OS                       | `amazoncorretto:11-alpine`                                                                                                                                    | Debian 13 (minimal)                                                                                                                                                                                                                                 |
| Default user                  | `reaper` (UID 1001)                                                                                                                                           | `nonroot` (UID 65532)                                                                                                                                                                                                                               |
| Entrypoint                    | Bash wrapper (`entrypoint.sh`) that copies the config template, runs `configure-*.sh` helpers to template ~70 environment variables, and `exec`s `java`       | `java -jar /usr/local/share/cassandra-reaper/cassandra-reaper.jar` (direct)                                                                                                                                                                         |
| Default command               | `cassandra-reaper`                                                                                                                                            | `server /etc/cassandra-reaper/cassandra-reaper.yaml`                                                                                                                                                                                                |
| JVM flags                     | Wrapper sets `-Xms${REAPER_HEAP_SIZE} -Xmx${REAPER_HEAP_SIZE}` and reads `JAVA_OPTS`                                                                          | No wrapper; set `JAVA_TOOL_OPTIONS` instead (picked up automatically by the JVM)                                                                                                                                                                    |
| Config templating             | `configure-persistence.sh` / `configure-metrics.sh` / `configure-*.sh` append sections to the config at runtime based on ~70 `REAPER_*` environment variables | Only `REAPER_AUTH_ENABLED`, `REAPER_AUTH_USER`, `REAPER_AUTH_PASSWORD`, `REAPER_READ_USER`, and `REAPER_READ_USER_PASSWORD` are substituted. For other settings, bind-mount a custom config file over `/etc/cassandra-reaper/cassandra-reaper.yaml` |
| Default `REAPER_AUTH_ENABLED` | `true` (container fails to start without `REAPER_AUTH_USER` + `REAPER_AUTH_PASSWORD`)                                                                         | `false` (container boots without any env vars; set `REAPER_AUTH_ENABLED=true` plus credentials to enable authentication)                                                                                                                            |
| `spreaper` CLI                | Available in the `-spreaper` image variant                                                                                                                    | Not shipped; exec it directly from a separate Python container if needed                                                                                                                                                                            |
| `register-clusters` CLI       | Available as a sub-command of `entrypoint.sh`                                                                                                                 | Not shipped; call the Reaper REST API directly (`POST /cluster`)                                                                                                                                                                                    |
| Declared volumes              | `/var/lib/cassandra-reaper`, `/etc/cassandra-reaper/shiro`, `/etc/cassandra-reaper/config`                                                                    | No `VOLUME` metadata (DHI convention); `/var/lib/cassandra-reaper`, `/var/log/cassandra-reaper`, and `/var/tmp/cassandra-reaper` are writable by the default user so you can mount host paths over them                                             |
| Shell in runtime image        | Yes (`bash`)                                                                                                                                                  | No                                                                                                                                                                                                                                                  |

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. The Cassandra Reaper FIPS variant uses a FIPS-validated OpenSSL provider together with the
  Bouncy Castle FIPS Java provider that ship with the Docker Hardened Images Eclipse Temurin JRE. All TLS/JSSE
  operations performed by Reaper (for example, JMX-over-SSL, HTTPS connections to Cassandra, PostgreSQL JDBC with SSL)
  transparently use FIPS-approved algorithms when you run a FIPS variant.

  ```
  docker run --rm -p 8080:8080 -p 8081:8081 dhi.io/cassandra-reaper:4-fips
  ```

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use the `static` image for runtime.                                                                                                                                                                                 |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | Some images, such as static, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                                       |

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
