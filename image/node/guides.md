## How to use this image

### Start a Node.js instance

Run the following command to run a Nodejs container. Replace `<your-namespace>` with your organization's namespace and
`<tag>` with the image variant you want to run.

```
$ docker run --rm <your-namespace>/dhi-node:<tag> node --version
```

### Getting Started

In this example, you'll see how to create a basic HTTP server that responds with a greeting message. The server will
listen on port `3000` and demonstrate the key characteristics of Docker Hardened Node.js images, including running as a
nonroot user and using non-privileged ports.

First, let's create a project structure:

```
mkdir -p ~/hello-world-node/src && cd ~/hello-world-node
```

This creates the following folder structure and sets our working directory to the root `hello-world-node` folder:

```
hello-world-node
└── src
```

Now let's create a `package.json` file, which provides metadata about the project, including dependencies:

```
cat << 'EOF' > package.json
{
  "name": "hello-world-app",
  "version": "1.0.0",
  "description": "Simple Node.js hello world server",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js"
  },
  "dependencies": {}
}
EOF
```

The above defines a package, `hello-world-app`, with no external dependencies that will run the code in `src/index.js`
when started.

Let's create our application code now.

```
cat << 'EOF' > src/index.js
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Hello World from Docker Hardened Node.js!\n');
});

const port = process.env.PORT || 3000;
server.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});
EOF
```

This application code creates a simple HTTP server using Node.js built-in http module. The server listens on port `3000`
(or the PORT environment variable) and responds to all requests with a greeting message.

Finally, let's create a Dockerfile for our image build:

```
cat << 'EOF' > Dockerfile
# syntax=docker/dockerfile:1
# Use dev variant for building
FROM <your-namespace>/dhi-node:<tag>-dev AS build-stage

ENV NODE_ENV=production
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies and ensure node_modules exists
RUN npm i --omit=dev && mkdir -p node_modules

# Use runtime variant for final image
FROM <your-namespace>/dhi-node:<tag> AS runtime-stage

ENV NODE_ENV=production
WORKDIR /usr/src/app

# Copy node_modules from build stage
COPY --from=build-stage /usr/src/app/node_modules ./node_modules

# Copy application code
COPY src ./src
COPY package*.json ./

# Expose port (use non-privileged port)
EXPOSE 3000

# Start the application
CMD ["node", "src/index.js"]
EOF
```

This Dockerfile uses a multi-stage build with the `-dev` variant for building and the `runtime` variant for the final
image. It sets the `NODE_ENV` environment variable to production, copies our application files, and runs our Node.js
server.

### Build and run the image

```
docker build -t hello-world-node .
```

Finally, run the container:

```
docker run --rm -p 3000:3000 --name hello-world-app hello-world-node
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
Hello World from Docker Hardened Node.js!
```

You can also visit `http://localhost:3000` in your browser to see the same message.

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature             | Docker Official Node.js             | Docker Hardened Node.js                             |
| ------------------- | ----------------------------------- | --------------------------------------------------- |
| **Security**        | Standard base with common utilities | Minimal, hardened base with security patches        |
| **Shell access**    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| **Package manager** | npm/yarn available in all variants  | npm/yarn only available in dev variants             |
| **User**            | Runs as root by default             | Runs as nonroot user                                |
| **Attack surface**  | Larger due to additional utilities  | Minimal, only essential components                  |
| **Debugging**       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager in runtime variants?

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
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. Docker Hardened Node.js images include FIPS-compliant variants for environments requiring
Federal Information Processing Standards compliance.

#### Steps to verify FIPS:

```shell
# Check FIPS status (should return 1 for enabled)
$ docker run --rm <your-namespace>/dhi-node:<tag>-fips \
  node -e "console.log('FIPS status:', require('crypto').getFips ? require('crypto').getFips() : 'FIPS method not available')"

# Verify cipher restrictions (FIPS has significantly fewer available)
$ docker run --rm <your-namespace>/dhi-node:<tag>-fips \
  node -e "console.log('FIPS ciphers:', require('crypto').getCiphers().length)"

$ docker run --rm <your-namespace>/dhi-node:<tag> \
  node -e "console.log('Non-FIPS ciphers:', require('crypto').getCiphers().length)"

# Test disabled cryptographic functions (MD5 disabled in FIPS)
$ docker run --rm <your-namespace>/dhi-node:tag>-fips \
  node -e "
  try {
    require('crypto').createHash('md5').update('test').digest('hex');
    console.log('MD5: Available');
  } catch(e) {
    console.log('MD5: Disabled -', e.message);
  }"
```

#### Runtime requirements specific to FIPS:

- FIPS mode enforces stricter cryptographic standards
- Weak cryptographic functions like MD5 are disabled and will fail at runtime
- Applications using restricted algorithms may need modification
- Only FIPS-approved cryptographic algorithms are available (~60% fewer than non-FIPS)

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                            |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

### Migrate to a Docker Hardened Image

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   Node.js images are available in versions 18, 20, 22 and 24

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
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the **Tags** tab for this repository. To view what packages are already installed in an image variant, select
   the **Tags** tab for this repository, and then select a tag.

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

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Tags** tab for this repository.

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

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
