## How to use this image

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository** > **Mirror to
repository**, and then follow the on-screen instructions.

## Start a Filebeat instance

Run the following command to run a Filebeat container. Replace `<your-namespace>` with your organization's namespace and
`<tag>` with the image variant you want to run.

```console
docker run --rm  <your-namespace>/dhi-filebeat:<tag> version
```

This command runs Filebeat and prints the version information. The entry point is `filebeat` so you can pass any
`filebeat` command or flags directly.

## Common Filebeat use cases

### Run Filebeat with Compose and a custom configuration

This example shows Filebeat shipping logs to Elasticsearch with Kibana for visualization. It uses a custom
`filebeat.yml` configuration file and mounts a local `logs` directory into the container to read log files.

First, create a `compose.yaml` file:

```yaml
services:
  elasticsearch:
    image: <your-namespace>/dhi-elasticsearch:<tag>
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"

  kibana:
    image: <your-namespace>/dhi-kibana:<tag>
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    volumes:
      - kibana_conf:/opt/kibana/kibana-<tag>/config

  filebeat:
    image: <your-namespace>/dhi-filebeat:<tag>
    volumes:
      - ./filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - ./logs:/var/log:ro
    depends_on:
      - elasticsearch

volumes:
  kibana_conf:
```

Then, create a `filebeat.yml` configuration file:

```yaml
filebeat.inputs:
- type: filestream
  enabled: true
  paths:
    - /var/log/*.log

output.elasticsearch:
  hosts: ["elasticsearch:9200"]

processors:
- add_host_metadata:
    when.not.contains.tags: forwarded
```

Run the Compose stack:

```console
docker compose up -d
```

View logs in Kibana at http://localhost:5601

For more configuration options see the
[official Filebeat documentation](https://www.elastic.co/guide/en/beats/filebeat/current/index.html).

### Use Filebeat in Kubernetes

To use the Filebeat hardened image in Kubernetes, [set up authentication](https://docs.docker.com/dhi/how-to/k8s/) and
update your Kubernetes deployment. For example, in your `filebeat.yaml` file, replace the image reference in the
container spec. In the following example replace `<your-namespace>` and `<tag>` with your organization's namespace and
the desired tag.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filebeat
  namespace: <kubernetes-namespace>
spec:
  template:
    spec:
      containers:
        - name: filebeat
          image: <your-namespace>/dhi-filebeat:<tag>
      imagePullSecrets:
        - name: <your-registry-secret>
```

Then apply the manifest to your Kubernetes cluster.

```console
$ kubectl apply -n <kubernetes-namespace> -f filebeat.yaml
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. The Filebeat image only comes in the
runtime variant. Runtime variants are designed to run your application in production. These images are intended to be
used either directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

## Non-hardened image vs. Docker Hardened Image

### Key differences

| Feature         | Non-hardened Filebeat                               | Docker Hardened Filebeat                            |
| --------------- | --------------------------------------------------- | --------------------------------------------------- |
| Base image      | Red Hat UBI                                         | Debian 13                                           |
| User            | Runs as user ID 1000 (`filebeat` user)              | Runs as user ID 1000 (`nonroot` user)               |
| Entrypoint      | `/usr/bin/tini -- /usr/local/bin/docker-entrypoint` | Direct `filebeat` binary                            |
| Shell access    | Shell available                                     | No shell available                                  |
| Package manager | `microdnf` available                                | No package manager available                        |
| Default command | `--environment container`                           | HTTP monitoring enabled with Unix socket            |
| Attack surface  | Larger due to additional utilities                  | Minimal, only contains essential components         |
| Debugging       | Traditional shell debugging                         | Use Docker Debug or image mount for troubleshooting |

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
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=<your-namespace>/dhi-busybox,destination=/dbg,ro \
  <your-namespace>/<image-name>:<tag> /dbg/bin/sh
```

## Migrate to a Docker Hardened Image

Migrating to the hardened Filebeat image requires some adjustments due to differences in entrypoint and default
behavior. While most configuration remains compatible, you'll need to account for the streamlined approach of the
hardened image.

### Migration steps

1. Update your image reference.

   Replace the image reference in your Docker run command or Compose file:

   - From: `docker.elastic.co/beats/filebeat:<tag>`
   - To: `<your-namespace>/dhi-filebeat:<tag>`

1. Adjust command arguments if needed.

   The hardened image uses a direct `filebeat` entrypoint instead of the tini wrapper.

   If you override the default command, ensure your arguments are compatible with the `filebeat` binary directly.

1. Verify configuration compatibility.

   Your existing environment variables, volume mounts, and network settings should remain the same, but test thoroughly
   as the hardened image may behave differently in edge cases.

### General migration considerations

While the specific configuration requires no changes, be aware of these general differences in Docker Hardened Images:

| Item            | Migration note                                                         |
| --------------- | ---------------------------------------------------------------------- |
| Base images     | Based on hardened Debian, not Red Hat UBI                              |
| Shell access    | No shell in runtime variants, use Docker Debug for troubleshooting     |
| Package manager | No package manager in runtime variants                                 |
| Debugging       | Use Docker Debug or image mount instead of traditional shell debugging |

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
the host.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
