## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this OpenSearch Dashboards image

This Docker Hardened OpenSearch Dashboards image includes:

- OpenSearch Dashboards web interface for data visualization and exploration
- All standard OpenSearch Dashboards plugins bundled in a standard installation

## Start a OpenSearch Dashboards image

### Basic usage

Create user defined network (useful for connecting to other services attached to the same network (e.g. OpenSearch)):

```bash
$ docker network create opensearch-net
```

Run the following command to run an OpenSearch Dashboards container:

```bash
$ docker run -d --name opensearch-dashboards --net opensearch-net -p 5601:5601 \
  dhi.io/opensearch-dashboards:<tag>
```

### With Docker Compose (recommended for complex setups)

```yaml
version: '3.8'
services:
  opensearch-node1:
    image: dhi.io/opensearch:<tag>
    container_name: opensearch-node1
    environment:
      - cluster.name=opensearch-cluster
      - node.name=opensearch-node1
      - discovery.seed_hosts=opensearch-node1,opensearch-node2
      - cluster.initial_cluster_manager_nodes=opensearch-node1,opensearch-node2
      - bootstrap.memory_lock=true
      - "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m"
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=${OPENSEARCH_INITIAL_ADMIN_PASSWORD}
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - opensearch-data1:/usr/share/opensearch/data
    ports:
      - 9200:9200
      - 9600:9600
    networks:
      - opensearch-net

  opensearch-node2:
    image: dhi.io/opensearch:<tag>
    container_name: opensearch-node2
    environment:
      - cluster.name=opensearch-cluster
      - node.name=opensearch-node2
      - discovery.seed_hosts=opensearch-node1,opensearch-node2
      - cluster.initial_cluster_manager_nodes=opensearch-node1,opensearch-node2
      - bootstrap.memory_lock=true
      - "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m"
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=${OPENSEARCH_INITIAL_ADMIN_PASSWORD}
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - opensearch-data2:/usr/share/opensearch/data
    networks:
      - opensearch-net

  opensearch-dashboards:
    image: dhi.io/opensearch-dashboards:<tag>
    container_name: opensearch-dashboards
    environment:
      - opensearch.hosts=http://opensearch-node1:9200
    ports:
      - 5601:5601
    networks:
      - opensearch-net
    depends_on:
      - opensearch-node1

volumes:
  opensearch-data1:
  opensearch-data2:

networks:
  opensearch-net:
```

### Environment variables

The following environment variables are commonly used to configure OpenSearch Dashboards:

| Variable              | Description                                       | Default                 | Required |
| --------------------- | ------------------------------------------------- | ----------------------- | -------- |
| `server.name`         | Sets the name of the OpenSearch Dashboards server | `opensearch-dashboards` | No       |
| `server.host`         | Sets the host address for the server              | `0.0.0.0`               | No       |
| `opensearch.hosts`    | Comma-separated list of OpenSearch URLs           | `http://localhost:9200` | Yes      |
| `opensearch.username` | Username for connecting to OpenSearch             | None                    | No       |
| `opensearch.password` | Password for connecting to OpenSearch             | None                    | No       |

Example with environment variables:

```bash
$ docker run -d --name opensearch-dashboards --net opensearch-net -p 5601:5601 \
  -e opensearch.hosts=http://opensearch-node1:9200 \
  -e server.name=my-dashboards \
  dhi.io/opensearch-dashboards:<tag>
```

### Test the deployment

You can verify the OpenSearch Dashboards cluster is running by visting the dashboard from the browser or using curl:

```bash
$ curl http://localhost:5601
```

You should get a response containing cluster information and the OpenSearch Dashboards version.

## Common OpenSearch Dashboards use cases

### OpenSearch Dashboards with persistence

When you need to persist configuration or custom dashboards across container restarts:

```bash
$ docker run -d \
  -p 5601:5601 \
  -v opensearch-dashboards-config:/usr/share/opensearch-dashboards/config \
  -v opensearch-dashboards-data:/usr/share/opensearch-dashboards/data \
  dhi.io/opensearch-dashboards:<tag>
```

### OpenSearch Dashboards with custom configuration

For production deployments requiring specific configuration files. Create a custom `opensearch_dashboards.yml` file:

```yaml
# Example opensearch_dashboards.yml
server.host: "0.0.0.0"
server.port: 5601
server.name: "my-opensearch-dashboards"

opensearch.hosts: ["https://opensearch-node1:9200", "https://opensearch-node2:9200"]
opensearch.username: "admin"
opensearch.password: "admin"

opensearch.ssl.verificationMode: certificate
opensearch.ssl.certificateAuthorities: ["/usr/share/opensearch-dashboards/config/root-ca.pem"]

logging.level: info
logging.dest: stdout
```

Then mount the configuration file:

```bash
$ docker run -d \
  -p 5601:5601 \
  -v /path/to/custom-opensearch-dashboards.yml:/usr/share/opensearch-dashboards/config/opensearch_dashboards.yml \
  dhi.io/opensearch-dashboards:<tag>
```

### OpenSearch Dashboards with custom plugins

When you need additional plugins beyond the standard bundled ones:

```dockerfile
FROM dhi.io/opensearch-dashboards:<tag>
RUN /usr/share/opensearch-dashboards/bin/opensearch-dashboards-plugin install --batch <plugin-id>
```

Build and run the custom image:

```bash
$ docker build --tag=opensearch-dashboards-custom-plugin .
$ docker run -p 5601:5601 opensearch-dashboards-custom-plugin
```

For more information on configuring OpenSearch Dashboards, refer to the
[Configuring OpenSearch Dashboards documentation](https://docs.opensearch.org/docs/latest/install-and-configure/configuring-dashboards/index/).

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
