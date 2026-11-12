## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this harbor-portal Hardened image

This image contains the **Harbor Portal**, which provides the web-based user interface for Harbor registry management.
The Harbor Portal is a frontend application built with Angular and served by nginx, offering an intuitive graphical
interface for:

- Managing container registries and repositories
- Configuring security policies and access controls
- Monitoring replication and vulnerability scanning
- Administering users, projects, and system settings
- Viewing logs and system health metrics

The portal works in conjunction with other Harbor components like `harbor-core` (API server) to deliver a complete
container registry management experience.

## Start a harbor-portal instance

Run the following command and replace `<tag>` with the image variant you want to run.

**Important:** The Harbor Portal requires a backend Harbor Core server to handle API requests. The default nginx
configuration includes a placeholder `proxy_pass` directive that must be configured for your environment.

### Configure the backend server

The nginx configuration at `/etc/nginx/nginx.conf` proxies API requests to the Harbor Core backend. You must override
this configuration to point to your Harbor Core server.

**Mount a custom nginx configuration file**

Create a custom nginx.conf with your Harbor Core backend URL:

```nginx
# custom-nginx.conf
worker_processes auto;
pid /tmp/nginx.pid;

events {
    worker_connections  1024;
}

http {
    client_body_temp_path /tmp/client_body_temp;
    proxy_temp_path /tmp/proxy_temp;
    fastcgi_temp_path /tmp/fastcgi_temp;
    uwsgi_temp_path /tmp/uwsgi_temp;
    scgi_temp_path /tmp/scgi_temp;

    server {
        listen 8080;
        server_name  localhost;

        root   /usr/share/nginx/html;
        index  index.html index.htm;
        include /etc/nginx/mime.types;

        gzip on;
        gzip_min_length 1000;
        gzip_proxied expired no-cache no-store private auth;
        gzip_types text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript;

        location /devcenter-api-2.0 {
            try_files $uri $uri/ /swagger-ui-index.html;
        }

        location / {
            try_files $uri $uri/ /index.html;
        }

        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }

        # Replace with your Harbor Core backend URL
        location ~ ^/(api|c|chartrepo)/ {
            proxy_pass http://harbor-core:8080;
        }
    }
}
```

Then mount the configuration when running the container:

```bash
docker run -d --name harbor-portal \
  -p 8080:8080 \
  -v $(pwd)/custom-nginx.conf:/etc/nginx/nginx.conf:ro \
  dhi.io/harbor-portal:<tag>
```

### Verify the portal is running

```bash
docker run --rm -it dhi.io/harbor-portal:<tag> -h
```

Visit http://localhost:8080 to see the Harbor login page. Note that login and other functionality requires a working
connection to the Harbor Core backend.

## Common harbor-portal use cases

### Available harbor-portal options

The harbor-portal service provides these options:

```bash
# Main Options:
# -h               - Show help information

```

### Run as a daemon service

```bash
# Show help
docker run --rm dhi.io/harbor-portal:<tag> -h

docker run -d --name harbor-portal \
  -p 8080:8080 \
  dhi.io/harbor-portal:<tag>

# Test welcome page
curl http://localhost:8080
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened harbor-portal          | Docker Hardened harbor-portal                       |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

### Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug dhi.io/harbor-portal
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=<your-namespace>/dhi-busybox,destination=/dbg,ro \
  dhi.io/harbor-portal:<tag> /dbg/bin/sh
```

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

To migrate your application to a Docker Hardened Image, you must update your Kubernetes manifests or Docker
configurations. At minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This
and a few other common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base images in your Kubernetes manifests with a Docker Hardened Image.                                                                                                        |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                 |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                         |
| Ports              | Non-dev hardened images run as a nonroot user by default. `harbor-portal` typically binds to port 8080 for HTTP APIs. Because hardened images run as nonroot, avoid privileged operations. |
| Entry point        | The DHI harbor-portal image uses `nginx -g "daemon off;"` as its default command to serve the Harbor web UI. There is no custom entrypoint binary.                                         |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                |
| Environment config | When using harbor-portal in containers, ensure proper environment variable configuration for database and Redis connections.                                                               |

The following steps outline the general migration process.

1. **Find hardened images for your Harbor deployment.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   The harbor-portal service is the web-based user interface for Harbor registry management.

1. **Update your Harbor Helm chart configurations.**

   Update the image references in your Helm values or Harbor deployment configurations to use the hardened images:

   - From: `goharbor/harbor-portal:<tag>`
   - To: `dhi.io/harbor-portal:<tag>`

1. **For custom Harbor deployments, update the base image in your manifests.**

   If you're building custom Harbor deployments, ensure that your core pod uses the hardened harbor-portal as the main
   container image.

1. **Update environment configuration.**

   Ensure your deployments properly configure environment variables that harbor-portal needs for database connections,
   Redis cache, and other Harbor components.

1. **Test Harbor functionality.**

   After migration, verify that the Harbor web UI loads correctly and that you can navigate through the interface. The
   web UI is served by harbor-portal, while API endpoints like `/api/v2.0/health` are handled by the harbor-core
   component.

## Troubleshoot migration

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

`harbor-portal` requires read access to nginx configuration files and network connectivity to the harbor-core API
backend. Ensure your network configuration allows the nonroot user to connect to harbor-core when running in containers.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Harbor core
typically uses port 8080 which is not privileged.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
