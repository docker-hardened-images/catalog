## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a LINSTOR GUI image

The DHI LINSTOR GUI image uses a static nginx configuration file with default proxy settings. To customize the API
endpoints, you need to mount a custom nginx configuration file.

**Basic usage (with default configuration):**

```bash
docker run --name linstor-gui -p 8000:8000 \
  dhi.io/linstor-gui:<tag>
```

### Customizing nginx configuration

The default nginx configuration proxies requests to:

- `/v1` and `/metrics` → `http://localhost:3370` (LINSTOR API)
- `/api/v2` → `http://localhost:8080` (LINSTOR Gateway API)

To customize these endpoints, create your own `nginx.conf` file based on the default configuration and mount it into the
container. See the [Configuration examples](#configuration-examples) section below.

**With custom nginx configuration:**

```bash
docker run --name linstor-gui -p 8000:8000 \
  -v /path/to/nginx.conf:/etc/nginx/nginx.conf:ro \
  dhi.io/linstor-gui:<tag>
```

## Common use cases

### Deploy LINSTOR GUI with Docker Compose

**With custom nginx configuration:**

```yaml
version: '3.8'
services:
  linstor-gui:
    image: dhi.io/linstor-gui:<tag>
    ports:
      - "8000:8000"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - piraeus-server
```

### Configuration examples

**Example 1: Custom nginx.conf for different API hosts**

Create a file `nginx.conf`:

```nginx
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 8000;
        server_name localhost;

        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /v1 {
            proxy_pass http://piraeus-server:3370;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /metrics {
            proxy_pass http://piraeus-server:3370;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /api/v2 {
            proxy_pass http://piraeus-gateway:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
```

Then mount it:

```bash
docker run --name linstor-gui -p 8000:8000 \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
  dhi.io/linstor-gui:<tag>
```

**Example 2: Generate nginx.conf from environment variables (pre-container)**

If you need environment variable substitution, generate the config file before running the container:

```bash
# Create nginx.conf.template
cat > nginx.conf.template << 'EOF'
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 8000;
        server_name localhost;

        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /v1 {
            proxy_pass ${LB_LINSTOR_API_HOST};
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /metrics {
            proxy_pass ${LB_LINSTOR_API_HOST};
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /api/v2 {
            proxy_pass ${LB_GATEWAY_API_HOST};
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
EOF

# Generate nginx.conf using envsubst
export LB_LINSTOR_API_HOST=http://piraeus-server:3370
export LB_GATEWAY_API_HOST=http://piraeus-gateway:8080
envsubst < nginx.conf.template > nginx.conf

# Run container with generated config
docker run --name linstor-gui -p 8000:8000 \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
  dhi.io/linstor-gui:<tag>
```

## Non-hardened images vs. Docker Hardened Images

The upstream `linbit/linstor-gui` image (when built from source) uses an entrypoint script that:

1. Processes environment variables (`LB_LINSTOR_API_HOST` and `LB_GATEWAY_API_HOST`)
1. Substitutes these variables into an nginx configuration template
1. Starts nginx with the generated configuration

The Docker Hardened Image takes a different approach:

- **No entrypoint script**: The image runs `nginx` directly without shell scripts
- **Static configuration**: Uses a pre-configured `nginx.conf` file with default values
- **No shell**: The runtime image contains no shell (`/bin/sh`), `envsubst`, `sed`, or `awk`
- **Customization via volume mounts**: To customize API endpoints, mount your own `nginx.conf` file

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
