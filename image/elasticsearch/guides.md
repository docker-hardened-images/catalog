## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Run Elasticsearch

First, create a user defined network. This will make it easier to connect to other services attached to the same
network, like Kibana.

```
docker network create somenetwork
```

Run the following command to run an Elasticsearch container. Replace `<tag>` with the image variant you want to run.

```
docker run -d --name elasticsearch --net somenetwork -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" dhi.io/elasticsearch:<tag>
```

Next you need to reset the Elasticsearch password. Enter a bash shell for the container by running
`docker exec -it elasticsearch bash`, then run the following command. If you get an error locating the path for the
password reset tool, run `find / -type f -name "elasticsearch-reset-password" 2>/dev/null` to locate the full path and
replace it in the command below.

```
/opt/elasticsearch/elasticsearch-8.19.3/bin/elasticsearch-reset-password -u elastic -b
```

You should see a result like the following, note the newly generated password `<YOUR-ELASTIC-PASSWORD>`, you use it for
the following example CURL calls.

```
Password for the [elastic] user successfully reset.
New value: <YOUR-ELASTIC-PASSWORD>
```

### Common Elasticsearch use-cases

#### Check cluster health

```curl
curl -u elastic:<YOUR-ELASTIC-PASSWORD> -k "https://localhost:9200/_cluster/health?pretty"
```

#### Create an index

```curl
curl -u elastic:<YOUR-ELASTIC-PASSWORD> -k -X PUT "https://localhost:9200/my-index?pretty"
```

#### Index a document

```curl
curl -u elastic:<YOUR-ELASTIC-PASSWORD> -k -X POST "https://localhost:9200/my-index/_doc/1?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Elasticsearch Basics",
    "tags": ["docker", "search"],
    "published": "2025-09-30"
  }'
```

#### Retrieve a document

```curl
curl -u elastic:<YOUR-ELASTIC-PASSWORD> -k -X GET "https://localhost:9200/my-index/_doc/1?pretty"
```

#### Search documents

```curl
curl -u elastic:<YOUR-ELASTIC-PASSWORD> -k -X GET "https://localhost:9200/my-index/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": { "title": "Elasticsearch" }
    }
  }'
```

#### List all indices

```curl
curl -u elastic:<YOUR-ELASTIC-PASSWORD> -k "https://localhost:9200/_cat/indices?v"
```

#### Delete an index

```curl
curl -u elastic:<YOUR-ELASTIC-PASSWORD> -k -X DELETE "https://localhost:9200/my-index?pretty"
```

### Docker Compose example

To use Elasticsearch in a multi-service environment, create the following **docker-compose.yml**. This example adds
Kibana to the environment, note that `<YOUR-ELASTIC-PASSWORD>` is included in the Kibana config.

```
version: '3'
services:
  elasticsearch:
    image: dhi.io/elasticsearch:<tag>
    environment:
      - node.name=es01
      - discovery.type=single-node
    ports:
      - "9200:9200"

  kibana:
    image: dhi.io/kibana:<tag>
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=<YOUR-ELASTIC-PASSWORD>
      # Skip certificate verification if using self-signed cert
      - ELASTICSEARCH_SSL_VERIFICATIONMODE=none
```

Run the environment by running `docker compose up -d` in the same directory.

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
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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
