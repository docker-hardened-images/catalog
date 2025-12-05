## How to use this image

### Hosting some simple static content

To host some simple static content with this image, you can bind mount a directory of content to `/usr/share/nginx/html`
in the container. For example:

```
$ docker run --name some-nginx -v /some/content:/usr/share/nginx/html:ro -d <your-namespace>/dhi-nginx:<tag>
```

Alternatively, a simple Dockerfile can be used to generate a new image that includes the necessary content (which is a
much cleaner solution than the bind mount):

```
FROM <your-namespace>/dhi-nginx:<tag>
COPY static-html-directory /usr/share/nginx/html
```

Place this file in the same directory as your directory of content ("static-html-directory"), then run these commands to
build and start your container:

```
$ docker build -t some-content-nginx .
$ docker run --name some-nginx -d some-content-nginx
```

### Exposing external port

By default, this Nginx image listens on port 8080. To expose this port to the host, use the `-p` flag on `docker run`.
Assuming you've built the image as shown in the previous example, you can run:

```
$ docker run --name some-nginx -d -p 8080:8080 some-content-nginx
```

Then you can hit http://localhost:8080 or http://host-ip:8080 in your browser.

### Customize configuration

You can mount your configuration file, or build a new image with it.

If you wish to adapt the default configuration, you can use `cat` to output the default configuration file.

```
$ docker run --rm --entrypoint cat <your-namespace>/dhi-nginx:<tag> /etc/nginx/nginx.conf > nginx.conf
```

Then you can edit the contents in the new local file, and mount it into a new container.

```
$ docker run --name some-nginx -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro -d -p 8080:8080 <your-namespace>/dhi-nginx:<tag>
```

Or, build a new image with your configuration file.

```
FROM <your-namespace>/dhi-nginx:<tag>
COPY nginx.conf /etc/nginx/nginx.conf
```

### Using environment variables in Nginx configuration

Out-of-the-box, Nginx doesn't support environment variables inside most configuration blocks. But this image has a
function, which will extract environment variables before Nginx starts.

Here is an example using a Compose file.

```yaml
web:
  image: <your-namespace>/dhi-nginx:<tag>
  volumes:
   - ./templates:/etc/nginx/templates
  ports:
   - "8080:8080"
  environment:
   - NGINX_HOST=foobar.com
   - NGINX_PORT=8080
```

By default, this function reads template files in `/etc/nginx/templates/*.template` and outputs the result of executing
`envsubst` to `/etc/nginx/conf.d`.

So if you place `templates/default.conf.template` file, which contains variable references like this:

```
listen       ${NGINX_PORT};
```

It outputs to `/etc/nginx/conf.d/default.conf` like this:

```
listen       8080;
```

This behavior can be changed via the following environment variables:

- `NGINX_ENVSUBST_TEMPLATE_DIR`
  - A directory which contains template files (default: `/etc/nginx/templates`)
  - When this directory doesn't exist, this function will do nothing about template processing.
- `NGINX_ENVSUBST_TEMPLATE_SUFFIX`
  - A suffix of template files (default: `.template`)
  - This function only processes the files whose name ends with this suffix.
- `NGINX_ENVSUBST_OUTPUT_DIR`
  - A directory where the result of executing `envsubst` is output (default: `/etc/nginx/conf.d`)
  - The output filename is the template filename with the suffix removed. For example,
    `/etc/nginx/templates/default.conf.template` will be output with the filename `/etc/nginx/conf.d/default.conf`.
  - This directory must be writable by the user running a container.

### Running Nginx in read-only mode

To run Nginx in read-only mode, you will need to mount a Docker volume to every location where Nginx writes information.
The default Nginx configuration requires write access to `/var/cache/nginx` and `/var/run`. This can be easily
accomplished by running Nginx as follows:

```
$ docker run -d -p 8080:8080 --read-only -v $(pwd)/nginx-cache:/var/cache/nginx -v $(pwd)/nginx-pid:/var/run <your-namespace>/dhi-nginx:<tag>
```

If you have a more advanced configuration that requires Nginx to write to other locations, simply add more volume mounts
to those locations.

### Running Nginx in debug mode

`dev` variants include the `nginx-debug` binary that produces verbose output when using higher log levels. It can be
used with simple CMD substitution:

```
$ docker run --name my-nginx -v /host/path/nginx.conf:/etc/nginx/nginx.conf:ro -d <your-namespace>/dhi-nginx:<tag>-dev nginx-debug -g 'daemon off;'
```

Similar configuration in `compose.yaml` may look like this:

```yaml
web:
  image: <your-namespace>/dhi-nginx:<tag>-dev
  volumes:
    - ./nginx.conf:/etc/nginx/nginx.conf:ro
  command: [nginx-debug, '-g', 'daemon off;']
```

### Entrypoint quiet logs

A verbose entrypoint was added to the image. It provides information on what's happening during container startup. You
can silence this output by setting environment variable `NGINX_ENTRYPOINT_QUIET_LOGS`:

```
$ docker run -d -e NGINX_ENTRYPOINT_QUIET_LOGS=1 <your-namespace>/dhi-nginx:<tag>
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Nginx                  | Docker Hardened Nginx                               |
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

Switching to the hardened image does not require any special changes. You can use it as a drop-in replacement for the
standard Nginx image in your existing workflows and configurations.

### Migration steps

1. Update your image reference. Replace the image reference in your Docker run command or Compose file:
   - From: `nginx:<tag>`
   - To: `<your-namespace>/dhi-nginx:<tag>`
1. Update any necessary configuration. If you have custom configurations that rely on features not present in the
   hardened image (like running as root, exposing port 80, or using a shell), you will need to adjust them.

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
