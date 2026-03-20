## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Rust instance

Run the following command to run a Rust instance.

```
docker run --rm dhi.io/rust:<tag> rustc --version
```

Create a simple Rust program and run it directly from the container:

```
docker run -p 8000:8000 -v $(pwd):/app -w /app dhi.io/rust:<tag>-dev sh -c 'cat > main.rs << EOF
fn main() {
    println!("Hello from DHI Rust!");
}
EOF
rustc main.rs && ./main'
```

## Common Rust use cases

### Build and run a Rust application

The recommended way to use this image is to use a multi-stage Dockerfile with the `dev` variant as the build environment
and the `runtime` variant as the runtime environment. Before writing the Dockerfile, let's create the project files:

#### Step 1: Create Cargo.toml

```
cat > Cargo.toml << EOF
[package]
name = "docker-rust-hello"
version = "0.1.0"
edition = "2024"

[dependencies]
EOF
```

#### Step 2: Create `src` directory and `main.rs`

```
mkdir src
cat > src/main.rs << EOF
use std::io::prelude::*;
use std::net::{TcpListener, TcpStream};

fn main() {
    let listener = TcpListener::bind("0.0.0.0:8000").unwrap();
    println!("Server running on port 8000");

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        handle_connection(stream);
    }
}

fn handle_connection(mut stream: TcpStream) {
    let mut buffer = [0; 1024];
    stream.read(&mut buffer).unwrap();

    let response = "HTTP/1.1 200 OK\r\n\r\nHello from DHI Rust!";
    stream.write(response.as_bytes()).unwrap();
    stream.flush().unwrap();
}
EOF
```

#### Step 3: Generate the lock file

```
docker run --rm -v $(pwd):/app -w /app dhi.io/rust:<tag>-dev cargo generate-lockfile
```

#### Step 4. Create the Dockerfile

Create a Dockerfile with the following content to compile and run the project.

```Dockerfile
################################################################################
# Create a stage for building the application.
FROM dhi.io/rust:<tag>-dev AS build
WORKDIR /build

RUN --mount=type=bind,source=src,target=src \
    --mount=type=bind,source=Cargo.toml,target=Cargo.toml \
    --mount=type=bind,source=Cargo.lock,target=Cargo.lock \
    --mount=type=cache,target=/build/target/ \
    --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/ \
    cargo build --locked --release && \
    cp /build/target/release/docker-rust-hello /build/server

################################################################################
# Create a new stage for running the application with security-hardened runtime environment

FROM dhi.io/rust:<tag> AS final

# Copy the executable from the "build" stage.
COPY --from=build /build/server ./server


# Expose the port that the application listens on.
EXPOSE 8000

# What the container should run when it is started.
CMD ["./server"]
```

You can then build and run the Docker image:

```
docker build -t my-rust-app .
docker run -d -p 8000:8000 --name my-rust-app my-rust-app

# Test endpoints
curl http://localhost:8000/

# Clean up
docker stop my-rust-app && docker rm my-rust-app
```

## Docker Official Images vs Docker Hardened Images

### Key differences

| Feature                 | Docker Official Rust                  | Docker Hardened Rust                                                                     |
| ----------------------- | ------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Security**            | Standard base with common utilities   | Advanced security hardening with reduced attack surface via selective tool removal       |
| **Runtime environment** | Full shell and tools available        | Shell and Rust toolchain available, source control removed                               |
| **Toolchain**           | Same tools, same user                 | Same tools, secure user separation                                                       |
| **User security**       | Runs as root by default               | Secure non-root execution in runtime, root in dev                                        |
| **Attack surface**      | Larger due to additional utilities    | Reduced via user security + tool filtering                                               |
| **Debugging**           | Traditional shell debugging           | Advanced debugging with Docker Debug - comprehensive tools without compromising security |
| **Base OS**             | Various Alpine/Debian/Ubuntu versions | Security-hardened Alpine or Debian base                                                  |

### Why selective hardening with maintained functionality?

Docker Hardened Images provide enhanced security through targeted improvements:

- **Enhanced security**: Non-root user execution and source control tool removal
- **Maintained functionality**: Rust toolchain and shell access preserved for operational flexibility
- **User privilege separation**: Dev variants run as root for development needs, runtime variants run as nonroot
- **Selective tool removal**: Source control tools removed (both dev and runtime) while preserving essential development
  capabilities
- **Advanced debugging capabilities**: Docker Debug provides comprehensive debugging tools through an ephemeral, secure
  layer

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item                  | Migration note                                                                                                     |
| --------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Base image**        | Replace your base images in your Dockerfile with a Docker Hardened Image.                                          |
| **Nonroot user**      | Runtime images run as a nonroot user. Ensure that necessary files and directories are accessible to that user      |
| **Multi-stage build** | Utilize images with a dev tag for build stages and runtime images for runtime.                                     |
| **TLS certificates**  | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates. |
| **Ports**             | Non-dev hardened images run as a nonroot user by default. Configure your Rust application to use ports above 1024. |
| **Entry point**       | Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                           |

### Migration process

1. **Find hardened images for your app.** A hardened image may have several variants. Inspect the image tags and find
   the image variant that meets your needs. Rust images are available in multiple versions.

1. **Update the base image in your Dockerfile.** Update the base image in your application's Dockerfile to the hardened
   image you found in the previous step. For Rust applications, this is typically going to be an image tagged as `dev`
   because it has the Rust toolchain needed to compile applications.

   Example:

   ```dockerfile
   FROM dhi.io/rust:<version>-dev
   ```

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.** To ensure that your final image is as
   minimal as possible, you should use a multi-stage build. Use dev images for build stages and runtime images for final
   runtime.

1. **Install additional packages** Docker Hardened Images selectively remove certain tools while maintaining operational
   capabilities. You may need to install additional packages in your Dockerfile.

   Both dev and runtime variants include cargo and rustc. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then copy any necessary artifacts to the
   runtime stage that uses a minimal image.

## Troubleshoot migration

### General debugging

Docker Hardened Images provide robust debugging capabilities through **Docker Debug**, which attaches comprehensive
debugging tools to running containers while maintaining the security benefits of minimal runtime images.

**Docker Debug** provides a shell, common debugging tools, and lets you install additional tools in an ephemeral,
writable layer that only exists during the debugging session:

```bash
docker debug <container-name>
```

**Docker Debug advantages:**

- Full debugging environment with shells and tools
- Temporary, secure debugging layer that doesn't modify the runtime container
- Install additional debugging tools as needed during the session
- Perfect for troubleshooting DHI containers while preserving security

### Permissions

Runtime image variants run as the nonroot user. Ensure that necessary files and directories are accessible to that user.
You may need to copy files to different directories or change permissions so your application running as a nonroot user
can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure your
Rust applications to listen on ports 8000, 8080, or other ports above 1024.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
