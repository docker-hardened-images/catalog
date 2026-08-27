## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a Bun container

Replace `<tag>` with the image variant you want to run.

```console
$ docker run -it --rm dhi.io/bun:<tag>
```

This will start an interactive Bun shell where you can run JavaScript code directly.

## Common use cases

### Create and run a Bun application

1. Create a project directory and initialize a new Bun project, using the dev image variant:

   ```console
   $ mkdir my-bun-app && cd my-bun-app
   $ docker run --rm -v "$(pwd):/app" -w /app dhi.io/bun:<tag>-dev bun init -y
   ```

1. Install dependencies for a web server, again use the dev variant:

   ```console
   $ docker run --rm -v "$(pwd):/app" -w /app dhi.io/bun:<tag>-dev bun add express
   ```

1. Create a simple Bun server by replacing the default `index.ts`:

   ```console
   cat > index.ts << 'EOF'
   const server = Bun.serve({
     port: 3000,
     fetch(req) {
       return new Response("Hello from Bun!");
     },
   });

   console.log(`Server running at http://localhost:${server.port}`);
   EOF
   ```

1. Run your server, using the runtime variant:

   ```
   $ docker run --rm -v "$(pwd):/app" -w /app -p 3000:3000 dhi.io/bun:<tag> bun run index.ts
   ```

1. Open your browser and navigate to `http://localhost:3000` to see the message from your Bun server.

### Using Bun as a package manager

Building on the previous example, you can use Bun's package management capabilities:

1. Add additional dependencies to your project, using the dev variant:

   ```console
   $ docker run --rm -v "$(pwd):/app" -w /app dhi.io/bun:<tag>-dev bun add @types/node
   ```

1. View your project's dependencies, using the dev variant:

   ```console
   $ docker run --rm -v "$(pwd):/app" -w /app dhi.io/bun:<tag>-dev bun install --dry-run
   ```

1. Update your `index.ts` to use the installed packages:

   ```console
   cat > index.ts << 'EOF'
   import { serve } from "bun";

   const server = serve({
     port: 3000,
     fetch(req) {
       const url = new URL(req.url);
       if (url.pathname === "/health") {
         return new Response("OK", { status: 200 });
       }
       return new Response("Hello from Bun with Express support!", {
         headers: { "Content-Type": "text/plain" },
       });
     },
   });

   console.log(`Server running at http://localhost:${server.port}`);
   EOF
   ```

1. Run your enhanced server:

   ```console
   $ docker run --rm -v "$(pwd):/app" -w /app -p 3000:3000 dhi.io/bun:<tag> bun run index.ts
   ```

1. Open your browser and navigate to `http://localhost:3000` to see the message from your Bun server.

### Building a Bun application with Docker

The recommended way to use this image is to use a Bun dev container as the build environment and the runtime image as
the application runtime environment. In your Dockerfile, writing something along the lines of the following will compile
and run your project. Replace `<tag>` with the image variant you want to run.

Create a Dockerfile:

```dockerfile
# Build stage
FROM dhi.io/bun:<tag>-dev AS build

WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY index.ts tsconfig.json ./
RUN bun build ./index.ts --outdir ./dist --target bun

# Runtime stage
FROM dhi.io/bun:<tag>

WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules

EXPOSE 3000
CMD ["bun", "run", "dist/index.js"]
```

Build and run your Docker image:

```console
$ docker build -t my-bun-app .
$ docker run -p 3000:3000 my-bun-app
```

Open your browser and navigate to `http://localhost:3000` to see the message from your Bun server.

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature           | Non-hardened Bun (oven/bun)                                  | Docker hardened runtime variant                   | Docker hardened dev variant                       |
| ----------------- | ------------------------------------------------------------ | ------------------------------------------------- | ------------------------------------------------- |
| Image variants    | `alpine`, `debian`, `debian-slim`, `distroless`              | Alpine and Debian base variants                   | Alpine and Debian with `-dev` suffix              |
| Security          | Standard image with basic utilities                          | Hardened build with security patches and metadata | Hardened build with security patches and metadata |
| Shell access      | Shell available (`/bin/sh` or `/bin/bash`) except distroless | No shell                                          | Shell available (`/bin/sh` or `/bin/bash`)        |
| Package manager   | Package manager available (`apk`/`apt`) except distroless    | No package manager                                | Package manager available (`apk`/`apt`)           |
| User              | Runs as `bun` user (UID 1000)                                | Runs as `nonroot` user (UID 65532)                | Runs as `root` user                               |
| Working directory | `/home/bun/app` (alpine, debian variants), `/` (distroless)  | `/build`                                          | `/build`                                          |
| Attack surface    | Full OS utilities and shell (except distroless)              | Only `bun`, `bunx`, and CA certificates           | Includes shell, package manager, and build tools  |
| Debugging         | Shell and OS utilities available (except distroless)         | Use Docker Debug or image mount                   | Shell and package manager available               |

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
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/<image-name>:<tag> /dbg/bin/sh
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

Migrating to the hardened Bun image requires understanding the distinction between dev and runtime variants. The key
difference is that runtime images are minimal and secure for production use, while dev images include the tools needed
for package management and building.

### Migration steps

1. Assess your use case and choose appropriate variants.

   Determine which variants you need:

   - For package management and building: Use `-dev` variants
   - For running applications: Use runtime variants

1. Update your image references.

   Replace the image reference in your Docker run command, Dockerfile, or Compose file:

   - From: `oven/bun:<tag>`
   - To: `dhi.io/bun:<tag>` (runtime) or `dhi.io/bun:<tag>-dev` (development)

1. Update multi-stage builds (if applicable).

   Modify your Dockerfile to use the appropriate variants for each stage. For example:

   ```dockerfile
   # Build stage - use dev variant
   FROM dhi.io/bun:<tag>-dev AS build
   # ... build steps ...

   # Runtime stage - use runtime variant
   FROM dhi.io/bun:<tag>
   # ... copy artifacts and run ...
   ```

1. Update application configuration.

   Make necessary adjustments for the hardened environment:

   - Working directory: Update paths if necessary from `/home/bun/app` to `/build`
   - Privileged ports: Configure your application to listen on ports 1025 or higher (runtime images run as nonroot user)

1. Test your migration.

   Build and run your updated configuration to ensure everything works correctly.

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
