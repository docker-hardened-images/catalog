## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

For full documentation, see the
[OpenSearch Docker documentation](https://docs.opensearch.org/docs/latest/install-and-configure/install-opensearch/docker).

### Run in development mode

Create user defined network (useful for connecting to other services attached to the same network (e.g. OpenSearch
Dashboards)):

```
docker network create opensearch-net
```

Run the following command to run an OpenSearch container. Replace `<tag>` with the image variant you want to run.

```
docker run -d --name opensearch --net opensearch-net -p 9200:9200 -p 9600:9600 -e "discovery.type=single-node" -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=<custom-admin-password>" dhi.io/opensearch:<tag>
```

### Basic single-node deployment

To start a single OpenSearch node for development:

```
docker run -d -p 9200:9200 -p 9600:9600 -e "discovery.type=single-node" -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=<custom-admin-password>" dhi.io/opensearch:<tag>
```

### Disable security for development

For development purposes, you can disable the security plugin:

```
docker run -d -p 9200:9200 -p 9600:9600 -e "discovery.type=single-node" -e "DISABLE_SECURITY_PLUGIN=true" -e "DISABLE_INSTALL_DEMO_CONFIG=true" dhi.io/opensearch:<tag>
```

### Test the deployment

You can verify the OpenSearch cluster is running by sending a request to port 9200:

```
curl https://localhost:9200 -ku admin:<custom-admin-password>
```

You should get a response containing cluster information and the OpenSearch version.

### Further configuration & customization

#### Environment variables

The following environment variables are commonly used to configure OpenSearch:

##### Basic node configuration

- `cluster.name`: Sets the name of the OpenSearch cluster
- `node.name`: Sets the name of the OpenSearch node

##### Security and authentication

- `OPENSEARCH_INITIAL_ADMIN_PASSWORD`: Sets the admin user password (required for OpenSearch 2.12+)
- `DISABLE_INSTALL_DEMO_CONFIG`: Set to "true" to disable demo security configuration
- `DISABLE_SECURITY_PLUGIN`: Set to "true" to disable the security plugin entirely

##### Java and memory settings

- `OPENSEARCH_JAVA_OPTS`: Set JVM options (e.g., "-Xms512m -Xmx512m")
- `bootstrap.memory_lock`: Set to "true" to disable JVM heap memory swapping

##### Cluster discovery and management

- `discovery.type`: Set to "single-node" for single-node clusters
- `discovery.seed_hosts`: Comma-separated list of nodes to look for when discovering the cluster
- `cluster.initial_cluster_manager_nodes`: Comma-separated list of nodes that can serve as cluster manager
- `node.roles`: Defines one or more roles for an OpenSearch node. Valid values are `cluster_manager`, `data`, `ingest`,
  `search`, `ml`, `remote_cluster_client`, and `coordinating_only`.

##### More configuration options

- For more information on configuring OpenSearch, refer to the
  [Configuring OpenSearch documentation](https://docs.opensearch.org/docs/latest/install-and-configure/configuring-opensearch/index/).
- See the
  [various configuration related articles](https://docs.opensearch.org/docs/latest/install-and-configure/configuring-opensearch/index/)
  in the OpenSearch documentation.

#### Customize OpenSearch via configuration files

You can mount custom configuration files. For example, to use a custom `opensearch.yml` file, create a file and replace
`/path/to/custom-opensearch.yml` with the path to your custom configuration file. And then run the following command
(make sure to replace `<tag>` and `<custom-admin-password>` with your values):

```
docker run -d \
  -p 9200:9200 \
  -p 9600:9600 \
  -v /path/to/custom-opensearch.yml:/usr/share/opensearch/config/opensearch.yml \
  -e "discovery.type=single-node" \
  -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=<custom-admin-password>" \
  dhi.io/opensearch:<tag>
```

or the docker compose equivalent:

```yaml
services:
  opensearch:
    image: dhi.io/opensearch:<tag>
    container_name: opensearch
    environment:
      - discovery.type=single-node
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=<custom-admin-password>
    volumes:
      - /path/to/custom-opensearch.yml:/usr/share/opensearch/config/opensearch.yml
    ports:
      - 9200:9200
      - 9600:9600
```

### Multi-node cluster with Docker Compose

For production deployments, use Docker Compose to run a multi-node cluster. Create a `docker-compose.yml` file with the
following content, replacing `<tag>` with your values, and set the `OPENSEARCH_INITIAL_ADMIN_PASSWORD` environment
variable in your shell or `.env` file:

```yaml
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

volumes:
  opensearch-data1:
  opensearch-data2:

networks:
  opensearch-net:
```

### Password requirements

OpenSearch enforces strong password security using the zxcvbn password strength estimation library. Passwords must meet
the following requirements:

- Minimum length: 8 characters
- Maximum length: 100 characters
- Must contain at least one lowercase letter, one uppercase letter, one digit, and one special character

### Host system settings

Refer to the
[OpenSearch documentation](https://docs.opensearch.org/docs/latest/install-and-configure/install-opensearch/index/#important-settings)
for recommended host system settings.

### Working with plugins

#### Built-in plugins

The DHI Opensearch image comes with all standard OpenSearch plugins that are bundled in a standard OpenSearch
installation.

To see a list of these plugins, refer to OpenSearch's
[list of bundled plugins](https://docs.opensearch.org/docs/latest/install-and-configure/plugins/#bundled-plugins).

#### Custom plugins

If you wish to use other plugins in addition to the ones included in the image, you can install them using the
`opensearch-plugin` command.

To use custom plugins, create a Dockerfile:

```dockerfile
FROM dhi.io/opensearch:<tag>
RUN /usr/share/opensearch/bin/opensearch-plugin install --batch <plugin-id>
```

Build and run the custom image:

```bash
docker build --tag=opensearch-custom-plugin .
docker run -p 9200:9200 -p 9600:9600 -e "discovery.type=single-node" -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=<custom-admin-password>" opensearch-custom-plugin
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
