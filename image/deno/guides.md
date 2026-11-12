## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a Deno instance

Run the following command to run a Deno container. Replace `<tag>` with the image variant you want to run.

```
$ docker run --rm dhi.io/deno:<tag> --version
```

### Getting Started

In this example, you'll see how to create a basic HTTP server that responds with a greeting message. The server will
listen on port `3000` and demonstrate the key characteristics of Docker Hardened Deno images, including running as a
nonroot user and using non-privileged ports.

First, let's create a project structure:

```
mkdir -p ~/hello-world-deno && cd ~/hello-world-deno
```

Now let's create a simple HTTP server application:

```
cat << 'EOF' > main.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const port = 3000;

const handler = (_request: Request): Response => {
  return new Response("Hello World from Docker Hardened Deno!\n", {
    status: 200,
    headers: { "content-type": "text/plain" },
  });
};

console.log(`Server running on port ${port}`);
await serve(handler, { port });
EOF
```

This application code creates a simple HTTP server using Deno's standard library. The server listens on port `3000` and
responds to all requests with a greeting message.

Finally, let's create a Dockerfile for our image build:

```
cat << 'EOF' > Dockerfile
# syntax=docker/dockerfile:1
FROM dhi.io/deno:<tag>

# Copy application code
COPY main.ts .

# Expose port (use non-privileged port)
EXPOSE 3000

# Start the application with network permissions
CMD ["run", "--allow-net", "main.ts"]
EOF
```

This Dockerfile uses the Docker Hardened Deno image, copies our application file, and runs it with the necessary network
permissions. Deno requires explicit permissions for network access, which is granted via the `--allow-net` flag.

### Build and run the image

```
docker build -t hello-world-deno .
```

Finally, run the container:

```
docker run --rm -p 3000:3000 --name hello-world-app hello-world-deno
```

You should see the following output:

```
Server running on port 3000
```

You can test the application by opening another terminal and running:

```
curl http://localhost:3000
```

This should produce the following output:

```
Hello World from Docker Hardened Deno!
```

You can also visit `http://localhost:3000` in your browser to see the same message.

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature            | Official Deno                       | Docker Hardened Deno                                |
| ------------------ | ----------------------------------- | --------------------------------------------------- |
| **Security**       | Standard base with common utilities | Minimal, hardened base with security patches        |
| **Shell access**   | Full shell (bash/sh) available      | No shell in runtime variants                        |
| **User**           | Runs as deno user                   | Runs as nonroot deno user                           |
| **Attack surface** | Larger due to additional utilities  | Minimal, only essential components                  |
| **Debugging**      | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell in runtime variants?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Application-level logging and monitoring

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

- For example, you can use Docker Debug:

```
$ docker debug <container-name>
```

to get a debug shell into any container or image, even if they don't contain a shell.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell
  - Contain only the minimal set of libraries needed to run the app

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item             | Migration note                                                                                                                                                                                                                                                                                                       |
| :--------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image       | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                            |
| Nonroot user     | By default, images intended for runtime run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                              |
| TLS certificates | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                   |
| Ports            | Hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point      | Docker Hardened Images may have different entry points than images such as official Deno images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                            |
| No shell         | By default, images intended for runtime don't contain a shell. Use Docker Debug for troubleshooting.                                                                                                                                                                                                                 |
| Permissions      | Deno's permission system requires explicit flags (e.g., `--allow-net`, `--allow-read`, `--allow-write`). Ensure your CMD or ENTRYPOINT includes the necessary permission flags.                                                                                                                                      |

### Migrate to a Docker Hardened Image

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   Deno images are available starting from version 2.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step.

1. Install additional packages if needed

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. To view what packages are already installed in an image variant,
   select the **Tags** tab for this repository, and then select a tag.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

### Privileged ports

Hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged
ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure
your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on the host.
For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use Docker Debug to debug containers with no
shell.

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than official Deno images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.

### Deno permissions

Deno requires explicit permission flags for security-sensitive operations. If your application fails with permission
errors, ensure you've included the necessary flags in your CMD or ENTRYPOINT:

- `--allow-net`: Network access
- `--allow-read`: File system read access
- `--allow-write`: File system write access
- `--allow-env`: Environment variable access
- `--allow-run`: Execute subprocesses

For example: `CMD ["run", "--allow-net", "--allow-read", "main.ts"]`
