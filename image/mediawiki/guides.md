## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a MediaWiki instance

The Docker Hardened MediaWiki image is based on the Docker Hardened PHP image PHP-FPM flavor. It is designed to run
alongside a web server such as Nginx or Apache. To run a basic MediaWiki instance with the Docker Hardened MediaWiki
image, use the following Docker Compose file:

```yaml
services:
   mediawiki:
      image: dhi.io/mediawiki:<tag>
      volumes:
         - document-root:/var/www/html
         - data:/var/www/data

   nginx:
      image: dhi.io/nginx:1-debian13
      ports:
         - "80:80"
      depends_on:
         - mediawiki
      volumes:
         - document-root:/var/www/html:ro
         - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro

volumes:
   document-root:
   data:
```

The Nginx configuration file (`nginx.conf`) should include the following basic configuration for MediaWiki:

```nginx
server {
    listen 80;

    # this config assumes that MediaWiki is installed into /var/www/html,
    # so LocalSettings.php would be located at /var/www/html/LocalSettings.php
    root /var/www/html;
    index index.php;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 60;

    # Uncomment the following code if you wish to use the installer/updater
    # installer/updater
    location /mw-config/ {
        # Do this inside of a location so it can be negated
        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_pass mediawiki:9000;
            fastcgi_index index.php;
        }
    }

    # Location for wiki's entry points
    location ~ ^/(index|load|api|thumb|opensearch_desc|rest|img_auth)\.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass mediawiki:9000;
        fastcgi_index index.php;
    }

    # Images
    location ~ ^/(mw-config)?/images/ {
        # Separate location for images/ so .php execution won't apply
        add_header X-Content-Type-Options "nosniff";
    }
    location /images/deleted {
        # Deny access to deleted images folder
        deny all;
    }
    # MediaWiki assets (usually images)
    location ~ ^/resources/(assets|lib|src) {
        try_files $uri 404;
        add_header Cache-Control "public";
        expires 7d;
    }
    # Assets, scripts and styles from skins and extensions
    location ~ ^/(skins|extensions)/.+\.(css|js|gif|jpg|jpeg|png|svg|wasm)$ {
        try_files $uri 404;
        add_header Cache-Control "public";
        expires 7d;
    }
    # License and credits files
    location ~ ^/(COPYING|CREDITS) {
        default_type text/plain;
    }

    # Handling for Mediawiki REST API, see [[mw:API:REST_API]]
    location /rest.php/ {
        try_files $uri $uri/ /rest.php?$query_string;
    }

    # Uncomment the following code for handling image authentication
    # Also add "deny all;" in the location for /images above
    #location /img_auth.php/ {
    #    try_files $uri $uri/ /img_auth.php?$query_string;
    #}

    # Handling for the article path (pretty URLs)
    location /wiki/ {
        rewrite ^/wiki/(?<pagename>.*)$ /index.php;
    }

    # Allow robots.txt in case you have one
    location = /robots.txt {
    }
    # Explicit access to the root website, redirect to main page (adapt as needed)
    location = / {
        return 301 /wiki/Main_Page;
    }

    # Every other entry point will be disallowed.
    # Add specific rules for other entry points/images as needed above this
    location / {
        return 404;
    }
}
```

Then start the services with:

```bash
docker-compose up -d
```

You can browse to `http://localhost` to access the MediaWiki instance and start the configuration. Once your are done
configuring, download the `LocalSettings.php` file, update the Docker Compose file to mount it into the container, and
restart the services.

```yaml
   mediawiki:
      image: dhi.io/mediawiki:<tag>
      volumes:
         - document-root:/var/www/html
         - data:/var/www/data
         - ./LocalSettings.php:/var/www/html/LocalSettings.php:ro # <-- Add this line
```

Then restart the container.

```bash
docker-compose up -d
```

Note that whenever you update the LocalSettings.php file, you need to restart the container to apply the changes. This
is because PHP uses opcode caching.

## Non-hardened images vs Docker Hardened Images

### Key differences

The following section is pre-written to apply to all images. Add any additional features that Engineering notes in their
template.

| Feature               | Docker Official MediaWiki           | Docker Hardened MediaWiki              |
| --------------------- | ----------------------------------- | -------------------------------------- |
| Security              | Standard base with common utilities | Minimal, hardened base                 |
| with security pathces |                                     |                                        |
| Shell access          | Full shell (bash/sh) available      | No shell in runtime                    |
| variants              |                                     |                                        |
| Package manager       | apt/apk available                   | No package manager in runtime variants |
| User                  | Runs as root by default             | Runs as nonroot user                   |
| Attack surface        | Larger due to additional utilities  | Minimal, only essential                |
| components            |                                     |                                        |
| Debugging             | Traditional shell debugging         | Use Docker Debug or Image Mount for    |
| troubleshooting       |                                     |                                        |

### Why no shell or package manager?

The following section is pre-written to apply to all images.

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
docker run --rm -it --pid container:my-image \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/<image-name>:<tag> /dbg/bin/sh
```

## Image variants

The following section is pre-written to apply to all images. If engineering notes image-specific notes, add them as
needed.

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

### Compat variants

Only include this section if this image has compat variants

Compat variants support more seamless usage of DHI as a drop-in replacement for upstream images, particularly for
circumstances that the ultra-minimal runtime variant may not fully support. These images typically:

- Run as the nonroot user
- Improve compatibility with upstream helm charts
- Include optional tools that are critical for certain use-cases"

## Migrate to a Docker Hardened Image

The following section is pre-written to apply to all image migrations. If engineering notes image-specific migration
steps, items, notes, etc. add them to this section as needed.

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item                                                                         | Migration note                                                  |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Base image                                                                   | Replace your base images in your Dockerfile with a Docker       |
| Hardened Image.                                                              |                                                                 |
| Package management                                                           | Non-dev images, intended for runtime, don't contain             |
| package managers. Use package managers only in images with a dev tag.        |                                                                 |
| Non-root user                                                                | By default, non-dev images, intended for runtime, run as        |
| the nonroot user. Ensure that necessary files and directories are accessible |                                                                 |
| to the nonroot user.                                                         |                                                                 |
| Multi-stage build                                                            | Utilize images with a dev tag for build stages and              |
| non-dev images for runtime. For binary executables, use a static image for   |                                                                 |
| runtime.                                                                     |                                                                 |
| TLS certificates                                                             | Docker Hardened Images contain standard TLS certificates        |
| by default. There is no need to install TLS certificates.                    |                                                                 |
| Ports                                                                        | Non-dev hardened images run as a nonroot user by default. As a  |
| result, applications in these images can't bind to privileged ports          |                                                                 |
| (below 1024) when running in Kubernetes or in Docker Engine versions older   |                                                                 |
| than 20.10. Redis default port 6379 works without issues.                    |                                                                 |
| Entry point                                                                  | Docker Hardened Images may have different entry points than     |
| images such as Docker Official Images. Inspect entry points for Docker       |                                                                 |
| Hardened Images and update your Dockerfile if necessary.                     |                                                                 |
| No shell                                                                     | By default, non-dev images, intended for runtime, don't contain |
| a shell. Use dev images in build stages to run shell commands and then copy  |                                                                 |
| artifacts to the runtime stage.                                              |                                                                 |

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

The following sections are pre-written and included with each image. If engineering notes additional migration
troubleshooting steps, include them as a separate H3 section. If there are image-specific notes for pre-written
migration troubleshooting sections, add them as needed.

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

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
