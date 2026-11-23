## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Replace `<tag>` with a runtime tag of this repository, either a Debian tag or a tag that ends in `-alpine`. The matching
build-time variant of a tag is `<tag>-dev`. For full product documentation, see https://openliberty.io/docs/.

### What's included in this Open Liberty image

This image contains the full Open Liberty runtime, so every Liberty feature is already installed, together with an
Eclipse Temurin 21 JRE and the container helper scripts from the upstream Open Liberty image. The following tools are on
the `PATH`:

- `server` — Creates, starts, stops, and packages Liberty servers. The default command runs `server run defaultServer`.
- `productInfo` — Reports the installed Liberty version and validates the installation.
- `securityUtility` — Encodes passwords and creates SSL certificates for Liberty servers.
- `configure.sh` — Upstream build helper that applies the optional server configuration snippets during an image build.

For example, to print the Liberty version:

```bash
docker run --rm dhi.io/open-liberty:<tag> productInfo version
```

To encode a password with AES for use in `server.xml`:

```bash
docker run --rm dhi.io/open-liberty:<tag> securityUtility encode --encoding=aes --key=<your-aes-key> <password>
```

### Start an Open Liberty server

```bash
docker run -d --name open-liberty -p 9080:9080 -p 9443:9443 dhi.io/open-liberty:<tag>
```

When the logs show `CWWKF0011I: The defaultServer server is ready to run a smarter planet`, open http://localhost:9080/
to see the Open Liberty welcome page. HTTPS is served on https://localhost:9443/ with a self-signed certificate that the
image generates on first start.

The default server configuration in `/config/server.xml` enables the `javaee-8.0` feature set. Server logs, including
`messages.log`, are written to `/logs`. To keep them after the container is removed, mount a volume there:

```bash
docker run -d --name open-liberty -p 9080:9080 -v liberty-logs:/logs dhi.io/open-liberty:<tag>
```

### Deploy an application

To try an application without building an image, mount a WAR file into the `dropins` directory. Liberty deploys it with
the file name as the context root, for example http://localhost:9080/myapp/:

```bash
docker run -d -p 9080:9080 -v "$(pwd)/myapp.war:/config/dropins/myapp.war:ro" dhi.io/open-liberty:<tag>
```

For production, build an image that contains your server configuration and application. The following `server.xml`
enables only the features the application needs:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<server description="myapp">
    <featureManager>
        <feature>pages-3.1</feature>
        <feature>mpHealth-4.0</feature>
    </featureManager>
    <mpHealth checkInterval="5s" />
    <httpEndpoint id="defaultHttpEndpoint" host="*" httpPort="9080" httpsPort="9443" />
    <webApplication location="myapp.war" contextRoot="/" />
</server>
```

Copy it and the application into the image with the same layout and `configure.sh` step as the upstream Open Liberty
image. Files must be owned by the `nonroot` user:

```dockerfile
FROM dhi.io/open-liberty:<tag>
COPY --chown=nonroot:nonroot src/main/liberty/config/ /config/
COPY --chown=nonroot:nonroot target/myapp.war /config/apps/
RUN configure.sh
```

Because the image already contains every Liberty feature, you don't need a `featureUtility installFeature` step.

### Use the dev variant as a build stage

When a build step needs root, such as installing packages with `apt-get` or `apk`, run it in the `dev` variant and copy
the result into the runtime variant. When `configure.sh` runs without interim fixes, it only writes under `/config`, so
copying `/config` carries its output to the runtime stage:

```dockerfile
FROM dhi.io/open-liberty:<tag>-dev AS build
COPY src/main/liberty/config/ /config/
COPY target/myapp.war /config/apps/
RUN configure.sh

FROM dhi.io/open-liberty:<tag>
COPY --from=build --chown=nonroot:nonroot /config/ /config/
```

### Use your own TLS certificate

On startup, the entrypoint imports a mounted `tls.crt` and `tls.key` from `/etc/x509/certs` into the server keystore,
replacing the generated self-signed certificate. Both files must be readable by UID `65532`. If they are not, the
container exits during startup:

```bash
docker run -d -p 9443:9443 -v "$(pwd)/certs:/etc/x509/certs:ro" dhi.io/open-liberty:<tag>
```

To read the certificate from another directory, set `TLS_DIR`, for example `-e TLS_DIR=/run/secrets/tls`.

### Kubernetes health probes

The image includes the upstream probe scripts in `/opt/ol/helpers/runtime/`. They read the files that Liberty's
file-based health checks write to `/output/health/`, so the server must enable the `mpHealth-4.0` feature with a
`checkInterval`, as in the `server.xml` example above. Without it, the probes fail. The scripts assume the Kubernetes
default `periodSeconds` of 10. Run the container as UID `65532`:

```yaml
containers:
  - name: myapp
    image: <your-registry>/myapp:<tag>
    securityContext:
      runAsNonRoot: true
      runAsUser: 65532
      runAsGroup: 65532
    ports:
      - containerPort: 9080
      - containerPort: 9443
    startupProbe:
      exec:
        command: ["/opt/ol/helpers/runtime/startupHealthCheck.sh"]
    livenessProbe:
      exec:
        command: ["/opt/ol/helpers/runtime/livenessHealthCheck.sh"]
    readinessProbe:
      exec:
        command: ["/opt/ol/helpers/runtime/readinessHealthCheck.sh"]
```

## Non-hardened images vs. Docker Hardened Images

| Item                   | Open Liberty Docker Official Image (`full`)                 | Docker Hardened Open Liberty                                                                                     |
| ---------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Java runtime           | IBM Semeru Runtime (OpenJ9), Java 8, in `/opt/java/openjdk` | Eclipse Temurin 21 JRE (HotSpot), in `/usr/lib/jvm/temurin-21`                                                   |
| User                   | UID `1001`, GID `0`                                         | `nonroot`, UID `65532`, GID `65532`                                                                              |
| Writable Liberty paths | All of `/opt/ol/wlp`, owned by `1001:0`                     | `/config`, `/output`, `/logs`, `/opt/ol/fixes`, `/opt/ol/wlp/usr/shared`, and `/etc/wlp`; the rest is root-owned |
| Shell in runtime image | `bash` and a full set of base OS utilities                  | `bash` and the core utilities that the helper scripts need                                                       |

### User and file ownership

Replace `--chown=1001:0` in upstream Dockerfiles with `--chown=nonroot:nonroot`. The Liberty installation in
`/opt/ol/wlp` is owned by root, so a server running as `nonroot` can only write to its configuration, output, and log
directories. The image doesn't support running as an arbitrary UID in group `0`, such as the OpenShift `restricted`
security context constraint: the entrypoint fails with `Permission denied` when it writes the keystore configuration.
Run the container as UID `65532`.

### Java runtime

Applications run on Java 21 with the HotSpot JVM instead of Java 8 with OpenJ9. Check that your application supports
Java 21. The OpenJ9 options and shared class cache settings from the upstream image (`JAVA_TOOL_OPTIONS`,
`OPENJ9_JAVA_OPTIONS`, `OPENJ9_SCC`) are not set. Don't set `OPENJ9_SCC=true` when you run `configure.sh`, because the
shared class cache helper isn't included and the build step fails.

Neither variant includes a JDK. Compile your application in a separate JDK build stage. Liberty's code generation tools
in `/opt/ol/wlp/bin/jaxb`, `jaxrs`, `jaxws`, `xmlBinding`, and `xmlWS` stop with `CWWKE0601E` because they need a Java
compiler. Liberty compiles JSP pages without a JDK.

At startup, the JVM prints two harmless `WARNING: Unknown module: jdk.management.agent` and `jdk.attach` lines because
the JRE doesn't contain those modules.

### Upstream features not included

- Liberty InstantOn (checkpoint and restore): `checkpoint.sh` and CRIU aren't included, so setting `WLP_CHECKPOINT`
  makes the container fail.
- `SERVICEABILITY_NAMESPACE`: the entrypoint can't relink `/liberty/logs` in the root-owned installation, and the
  container exits. Mount a volume at `/logs` instead.
- The `kernel-slim` flavor isn't provided. The image always contains the full runtime.

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
