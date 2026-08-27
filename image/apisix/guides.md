## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this APISIX image

This Docker Hardened APISIX image includes Apache APISIX in a single, security-hardened package. Apache APISIX is a
dynamic, real-time, high-performance API Gateway that provides rich traffic management features such as load balancing,
dynamic upstream, canary release, circuit breaking, authentication, observability, and more.

## Start a APISIX image

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run -d --name apisix \
  -p 9080:9080 \
  -e APISIX_STAND_ALONE=true \
  dhi.io/apisix:<tag>
```

To configure APISIX with a basic route:

```bash
docker exec -i apisix sh -c 'cat > /usr/local/apisix/conf/apisix.yaml <<_EOC_
routes:
  -
    id: httpbin
    uri: /*
    upstream:
      nodes:
        "httpbin.org": 1
      type: roundrobin
    plugin_config_id: 1

plugin_configs:
  -
    id: 1
    plugins:
      response-rewrite:
        body: "Hello APISIX\n"
    desc: "response-rewrite"
#END
_EOC_'
```

Test your APISIX instance:

```bash
curl http://127.0.0.1:9080/
```

## Common APISIX use cases

### Load balancing with multiple upstreams

Configure APISIX to distribute traffic across multiple backend servers for high availability and improved performance.

The following example demonstrates a round-robin load balancing configuration across three backend servers:

```yaml
routes:
  -
    id: load-balance-route
    uri: /api/*
    upstream:
      nodes:
        "backend1.example.com:8080": 1
        "backend2.example.com:8080": 1
        "backend3.example.com:8080": 1
      type: roundrobin
```

### Canary release deployment

Implement gradual rollouts by routing a percentage of traffic to new service versions while monitoring performance.

The following configuration routes 80% of traffic to the stable version and 20% to the canary version:

```yaml
routes:
  -
    id: canary-route
    uri: /service/*
    upstream:
      nodes:
        "stable.example.com:8080": 80
        "canary.example.com:8080": 20
      type: weight
```

### API authentication and security

Secure your APIs with built-in authentication plugins like key-auth, JWT, or OAuth 2.0.

The following example shows how to configure key authentication for your API endpoints:

```yaml
routes:
  -
    id: secure-api
    uri: /secure/*
    plugins:
      key-auth: {}
    upstream:
      nodes:
        "api.example.com:8080": 1
      type: roundrobin

consumers:
  -
    username: api-user
    plugins:
      key-auth:
        key: "your-secret-api-key"
```

### Circuit breaking for resilience

Protect your services from cascading failures with circuit breaking capabilities. The following configuration sets up a
circuit breaker that trips after 3 failures and recovers after 2 successful requests:

```yaml
routes:
  -
    id: resilient-route
    uri: /api/*
    plugins:
      api-breaker:
        break_response_code: 502
        unhealthy:
          http_statuses: [500, 503]
          failures: 3
        healthy:
          successes: 2
    upstream:
      nodes:
        "service.example.com:8080": 1
```

### Observability and monitoring

Enable comprehensive monitoring with built-in observability features for metrics, logging, and tracing. The following
example configures Prometheus metrics export on port 9091:

```yaml
global_rules:
  -
    id: 1
    plugins:
      prometheus:
        export_uri: /apisix/prometheus/metrics
        export_addr:
          ip: 0.0.0.0
          port: 9091
```

## Docker Official Images vs. Docker Hardened Images

### Key differences

| Feature         | Docker Official APISIX              | Docker Hardened APISIX                              |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| Configuration   | Same APISIX configuration           | Same APISIX configuration                           |
| Performance     | Standard performance                | Same performance with enhanced security             |

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

For example, you can use Docker Debug:

```bash
docker debug apisix
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:apisix \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/apisix:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run APISIX

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                              |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                   |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                  |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                      |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                          |
| Ports              | Non-dev hardened images run as a nonroot user by default. APISIX default ports (9080, 9443, 9180) work without issues as they are above 1024.                               |
| Entry point        | Docker Hardened APISIX images maintain the same entry point as the Apache-hosted version for compatibility.                                                                 |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |
| Configuration      | APISIX configuration remains identical to the Apache-hosted version, ensuring seamless migration.                                                                           |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

## Troubleshoot migration

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

For APISIX specifically:

- Configuration files in `/usr/local/apisix/conf/` must be readable by the nonroot user
- Log directories must be writable by the nonroot user
- Plugin directories must be accessible

### Privileged ports

Non-dev hardened images run as a nonroot user by default. APISIX uses the following default ports which are all
non-privileged (above 1024):

- 9080: HTTP traffic port
- 9443: HTTPS traffic port
- 9180: Admin API port

These ports work without any modifications in the hardened image.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

For APISIX configuration updates, consider:

- Using volume mounts for configuration files
- Using the Admin API for dynamic configuration
- Building custom images with pre-configured settings

### Entry point

Docker Hardened APISIX maintains compatibility with the Apache-hosted version, using the same entry point. No
modifications to your existing startup scripts should be necessary.

### APISIX-specific compatibility

The Docker Hardened APISIX image maintains full compatibility with the Apache-hosted version:

- All plugins function identically
- Configuration format remains unchanged
- Admin API operates the same way
- etcd integration (when configured) works without modification
