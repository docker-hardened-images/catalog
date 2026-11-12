## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

See the how-to
[work with containers and Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-how-to-custom-container)
for more information on how to deploy function apps on Azure using docker images.

## Start an azure-functions-base image

### Basic usage

This image ships the Azure Functions host with no language worker and no function code. A custom handler needs no
worker: it is a small HTTP server that the host starts and forwards each trigger to. The following app has one
HTTP-triggered function.

`host.json`:

```json
{
  "version": "2.0",
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  },
  "customHandler": {
    "description": {
      "defaultExecutablePath": "handler"
    },
    "enableForwardingHttpRequest": true
  }
}
```

`hello/function.json`:

```json
{
  "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": ["get"]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "res"
    }
  ]
}
```

`main.go`:

```go
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("FUNCTIONS_CUSTOMHANDLER_PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/api/hello", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, "hello from a custom handler")
	})

	log.Fatal(http.ListenAndServe(":"+port, nil))
}
```

`Dockerfile`:

```dockerfile
FROM dhi.io/golang:1-dev AS build

WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 go build -o /handler .

FROM dhi.io/azure-functions-base:<tag>

ENV FUNCTIONS_WORKER_RUNTIME=custom

WORKDIR /home/site/wwwroot
COPY host.json ./
COPY hello/function.json ./hello/
COPY --from=build /handler ./
```

Run `go mod init handler` once to create `go.mod`, then build the image and run it:

```
docker build -t my-function-app .
docker run --rm -p 8080:80 my-function-app
curl http://localhost:8080/api/hello
```

The host listens on port 80 inside the container and reads the function app from `/home/site/wwwroot`. To listen on
another port, for example when your platform does not allow a nonroot user to bind port 80, set `ASPNETCORE_URLS` (for
example `http://+:8080`). The extension bundle is part of the image, so the host does not download it. The host admin
API requires a function key, so a request to `http://localhost:8080/admin/host/status` returns `401` until you configure
one.

If you are testing this image on Apple Silicon (M1, M2, etc) use the following command to pull the image forcing the
correct platform:

```
docker pull --platform linux/amd64 dhi.io/azure-functions-base:<tag>
```

### What this image is for

This image ships the Azure Functions host with no language worker installed, as in upstream
`mcr.microsoft.com/azure-functions/base`. It's the right starting point for a custom handler, or for a custom
out-of-process worker for a language the catalog doesn't already publish.

If you need Node.js or Python function apps, use `dhi.io/azure-functions-node` or `dhi.io/azure-functions-python`
instead.

Azure Functions Core Tools are not included in this hardened image.

> [!NOTE]
>
> This hardened image can only run on the `linux/amd64` platform. For testing on Apple Silicon (M1, M2, M3), enable
> emulation.

## Non-hardened images vs. Docker Hardened Images

Compared with `mcr.microsoft.com/azure-functions/base`:

- The image runs as the nonroot user (uid 65532), not root. `/home/site/wwwroot` is owned by root, so your function app
  is read-only to the host process.
- The image starts the host directly. Upstream starts it through `/opt/startup/start_nonappservice.sh`, which first
  installs the CA certificates that it finds in `/var/ssl/root` and the Azure cloud certificates. This image does not do
  that. Add your own CA certificates to the image at build time.
- `HOME` is `/home/nonroot`, and `/root` in the `-dev` variants. Upstream sets it to `/home`. The paths
  `/home/nonroot/site` and `/root/site` link to `/home/site`, so the host finds your function app in all variants.
- The image ships extension bundle 4.x only. Upstream also ships bundles 2.x and 3.x.

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
