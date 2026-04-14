## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this openresty image

This Docker Hardened openresty image includes:

- OpenResty (NGINX + LuaJIT) installed at /opt/openresty
- nginx and openresty binaries for running the HTTP server
- LuaJIT runtime, luarocks and opm for managing Lua/OpenResty packages
- Default nginx config directory at /opt/openresty/nginx/conf (replaceable via volumes)
- Logs are symlinked to stdout/stderr for container logging; temporary files are placed in /var/run/openresty/

## Start an openresty image

Basic docker run (map host 80 to container 8080 to avoid privileged ports inside the container):

```bash
$ docker run --rm --name openresty -p 80:8080 \
  dhi.io/openresty:<tag> \
  -g "daemon off;" -c /opt/openresty/nginx/conf/nginx.conf
```

If you want to run inside the container on port 80, use a dev or privileged environment where binding to privileged
ports is allowed, or configure the server to listen on a non-privileged port inside the container and map host port 80
to it.

### Docker Compose example (reverse proxy + static content)

```yaml
version: '3.8'
services:
  web:
    image: dhi.io/openresty:<tag>
    container_name: openresty
    ports:
      - "8080:8080"
    volumes:
      - ./nginx.conf:/opt/openresty/nginx/conf/nginx.conf:ro
      - ./www:/usr/share/nginx/html:ro
      - openresty-client-temp:/var/run/openresty
    command: ["-g", "daemon off;", "-c", "/opt/openresty/nginx/conf/nginx.conf"]

volumes:
  openresty-client-temp:
```

## Environment and configuration

OpenResty configuration is driven primarily by nginx configuration files and Lua code. This image does not define a
large set of runtime environment variables; instead, configure behavior via nginx.conf and command-line arguments.

Common configuration locations and commands:

- Main nginx config: /opt/openresty/nginx/conf/nginx.conf
- Additional conf dirs: /opt/openresty/nginx/conf/conf.d (upstream users may add additional directories)
- Start command (image CMD): openresty -g "daemon off;"

| Variable / Method | Description                                                                              | Default                              | Required             |
| ----------------- | ---------------------------------------------------------------------------------------- | ------------------------------------ | -------------------- |
| nginx.conf (file) | Primary configuration file for OpenResty/Nginx. Use volumes to mount your custom config. | /opt/openresty/nginx/conf/nginx.conf | Yes (if customizing) |
| Command arguments | You can override the CMD by passing a different command to docker run.                   | openresty -g "daemon off;"           | No                   |

Example: run with a custom configuration file and mounted TLS certs:

```bash
$ docker run --rm --name openresty -p 443:8443 \
  -v $(pwd)/nginx.conf:/opt/openresty/nginx/conf/nginx.conf:ro \
  -v $(pwd)/certs:/etc/ssl/certs:ro \
  dhi.io/openresty:<tag> \
  -g "daemon off;" -c /opt/openresty/nginx/conf/nginx.conf
```

## Common openresty use cases

- Reverse proxy / load balancer in front of application servers (map upstreams in nginx.conf).
- API gateway and request routing using Lua scripts for authentication, rate-limiting, and request transformation.
- Serving static websites (mount static assets into the container and point nginx.conf to them).
- Web application firewall (WAF) or custom request filtering implemented with Lua.

## Configuration tips and best practices

- Keep your configuration files in version control and mount them read-only into the container.
- Symlink any custom access/error log paths to stdout/stderr so Docker logging drivers capture logs (the upstream image
  symlinks default logs already).
- Use non-privileged ports inside the container when running non-dev hardened images; map host ports to container ports
  (for example: `-p 80:8080`).
- Persist any temporary client body directories if you expect large request bodies by mounting /var/run/openresty.

## Nginx example snippets

Static content server (nginx.conf location - server block example):

```
server {
    listen 8080;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Reverse proxy to backend service (upstream example):

```
upstream backend {
    server backend:8080;
}

server {
    listen 8080;
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

*Everything below here is boilerplate and should be included verbatim!!!!! Be sure to remove this comment and keep
everything below this comment exactly as is.*

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
| Non-root user      | By default non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                    |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. In
   addition, update any stages that require a dev image to use a dev variant.

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
debugging applications built with Docker Debug (https://docs.docker.com/reference/cli/docker/debug/) to attach to these
containers. Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral,
writable layer that only exists during the debugging session.

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
