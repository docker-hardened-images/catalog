## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a Spark instance

By default, the security features on Spark are not enabled (see
[the Spark documentation](https://spark.apache.org/docs/latest/security.html#spark-security-things-you-need-to-know)).
The Docker Hardened Image for Spark, however, comes with authentication enabled by default. Nonetheless, you can turn it
off by setting the environment variable `SPARK_AUTHENTICATE` to `false`.

## Run Spark locally

To run Spark locally with as many worker threads as logical cores on your machine, run the following command. Replace
`<tag>` with the image variant you want to run.

For PySpark examples, use a `-python` variant:

```console
$ docker run --rm -it \
  dhi.io/spark:<tag>-python \
  driver --master "local[*]" \
  /opt/spark/examples/src/main/python/pi.py 10
```

For Scala/Java examples, use a standard variant:

```console
$ docker run --rm -it \
  dhi.io/spark:<tag> \
  /opt/spark/bin/spark-submit --master "local[*]" \
  --class org.apache.spark.examples.SparkPi \
  /opt/spark/examples/jars/spark-examples-jar 10
```

> [!WARNING]
>
> The FIPS variant will log warnings when legacy authentication and/or RPC encryption (`spark.authenticate` or
> `spark.network.crypto.enabled`) are enabled, as they are not FIPS compliant. Use TLS/SSL for RPC encryption instead
> (See [Spark security SSL options](https://spark.apache.org/docs/latest/security.html#ssl-configuration)).

## Notes about standalone mode

When running Spark on [Standalone mode](https://spark.apache.org/docs/latest/spark-standalone.html), since
authentication is enabled by default, you will have to provide a secret for the authentication to work. You can do this
by providing a config file that contains the secret.

Providing a secret in Kubernetes or Hadoop YARN is not mandatory as these resource managers have automatic secret
provisioning capabilities.

Create a `.spark-custom.conf` file next to your compose file:

```sh
spark.authenticate=true
spark.master.rest.enabled=false
spark.authenticate.secret="mySecureSecret"
# Alternative you could mount a secret file
# spark.authenticate.secret.file=/etc/spark/mysecret.key
```

Now use `docker compose up -d` to start master and workers

```yaml
services:
  master:
    image: dhi.io/spark:<tag>
    command: /opt/spark/sbin/start-master.sh
    ports:
      - "7077:7077"
      - "8080:8080"
    networks: ["sparknet"]
    volumes:
      - ./spark-custom.conf:/opt/spark/conf/spark-defaults.conf:ro

  worker-1:
    image: dhi.io/spark:<tag>
    command: ["/opt/spark/sbin/start-worker.sh", "spark://master:7077"]
    depends_on: [master]
    environment:
      SPARK_WORKER_CORES: "2"
      SPARK_WORKER_MEMORY: "1g"
    ports: ["8081:8081"]
    networks: ["sparknet"]
    volumes:
      - ./spark-custom.conf:/opt/spark/conf/spark-defaults.conf:ro

  worker-2:
    image: dhi.io/spark:<tag>
    command: ["/opt/spark/sbin/start-worker.sh", "spark://master:7077"]
    depends_on: [master]
    environment:
      SPARK_WORKER_CORES: "2"
      SPARK_WORKER_MEMORY: "1g"
    ports: ["8082:8081"]
    networks: ["sparknet"]
    volumes:
      - ./spark-custom.conf:/opt/spark/conf/spark-defaults.conf:ro

networks:
  sparknet:
    name: sparknet
```

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature            | Non-hardened image                   | Spark Docker Hardened Image (DHI)                   |
| ------------------ | ------------------------------------ | --------------------------------------------------- |
| Base OS            | Ubuntu-based                         | Hardened Debian-based                               |
| User context       | Runs as `spark` user (uid/gid 185)   | Runs as `nonroot` user (uid/gid 65532)              |
| Shell access       | Full shell with standard utilities   | Minimal shell for Spark scripts only                |
| Package management | Package manager included             | No package manager                                  |
| Attack surface     | Larger (500+ binaries and utilities) | Minimal (75% reduction in binaries)                 |
| Security posture   | Standard security metadata           | Ships with SBOM and VEX metadata                    |
| Vulnerabilities    | More CVEs from additional packages   | Significantly fewer CVEs from reduced dependencies  |
| Debugging          | Traditional shell debugging          | Use Docker Debug or image mount for troubleshooting |

### Why no package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's image mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```console
$ docker debug <image-name>
```

or mount debugging tools with the image mount feature:

```console
$ docker run --rm -it --pid container:my-container \
    --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
    dhi.io/<image-name>:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. The Spark hardened image provides
runtime variants, available both with and without Python support:

- Standard runtime variants include Apache Spark with Scala and Java support. These variants are designed to run Spark
  applications written in Scala or Java.

- Python-enabled runtime variants, tagged as `-python`, include Python support in addition to Scala and Java, enabling
  PySpark applications.

All runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a package manager
- Contain only the minimal set of libraries needed to run the app

## Migrate to a Docker Hardened Image

Switching to the hardened Spark image requires minimal changes for basic use cases. The hardened image uses the same
entry point as the standard Spark image. However, be aware that the hardened image runs as a nonroot user and does not
include a package manager, which may require adjustments to your deployment if you rely on these features.

### Migration steps

1. Update your image reference. Replace the image reference in your Docker run command or Compose file:

   - From: `apache/spark:<tag>` or similar
   - To: `dhi.io/spark:<tag>`

1. Choose the appropriate variant. Select a variant based on your needs:

   - For Scala/Java applications: Use a standard variant
   - For PySpark applications: Use a Python variant, tagged with `-python`

1. All your existing environment variables, volume mounts, and network settings remain the same.

### General migration considerations

While Spark-specific configuration requires minimal changes, be aware of these general differences in Docker Hardened
Images:

| Item             | Migration note                                                                                                                                                                                                                                                                                                               |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Package manager  | No package manager in runtime variants. Install dependencies in a custom Dockerfile using multi-stage builds if needed.                                                                                                                                                                                                      |
| User permissions | Runs as nonroot user (UID 65532). Ensure mounted volumes and files are accessible.                                                                                                                                                                                                                                           |
| Debugging        | Use Docker Debug or image mount instead of traditional shell debugging.                                                                                                                                                                                                                                                      |
| Ports            | Runtime hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime may not contain a shell nor any tools for debugging. The recommended method for
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

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
