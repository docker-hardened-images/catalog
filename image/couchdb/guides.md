## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this CouchDB image

This Docker Hardened CouchDB image includes the complete CouchDB database system in a single, security-hardened package:

- `couchdb`: The main CouchDB server
- `couchjs`: JavaScript runtime for CouchDB views and design documents
- Configuration tools and utilities for database administration

Unlike some other DHI images where runtime variants contain only the main binary, the CouchDB runtime image includes all
CouchDB tools. This design decision delivers maximum operational flexibility:

- Database administration tasks require command-line tools in production
- View and index operations need `couchjs` to be available
- Operational tasks often require these tools to be available
- This bundling provides a complete CouchDB toolkit in one security-hardened package

This approach aligns with real-world production use cases where CouchDB operations require more than just the server
binary.

## Start a CouchDB instance

Run the following command to start a CouchDB container. Replace `<tag>` with the image variant you want to run.

```bash
docker run --name some-couchdb -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=password -d -p 5984:5984 dhi.io/couchdb:<tag>
```

## Common CouchDB use cases

### Basic CouchDB server with admin access

Start CouchDB with an admin user:

```bash
docker run --name my-couchdb -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=mysecretpassword -d -p 5984:5984 dhi.io/couchdb:<tag>
```

Verify CouchDB is running:

```bash
curl http://admin:mysecretpassword@localhost:5984/
```

### CouchDB with network connectivity

Create a network and run CouchDB:

```bash
# Create a custom network
docker network create app-network

# Run CouchDB on the network
docker run --name my-couchdb -d \
  --network app-network \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=mysecretpassword \
  -p 5984:5984 \
  dhi.io/couchdb:<tag>
```

Applications running in Docker containers on the same network can now connect using 'my-couchdb' as the hostname. For
example: `http://admin:mysecretpassword@my-couchdb:5984`.

If your application is running outside Docker (or you need external access), the `-p 5984:5984` flag exposes the port on
the host.

### CouchDB with persistent data

Run CouchDB with data persistence using a Docker volume:

```bash
docker run --name couchdb-persistent -d \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=mysecretpassword \
  -v couchdb-data:/opt/couchdb/data \
  -p 5984:5984 \
  dhi.io/couchdb:<tag>
```

### Configure CouchDB with environment variables

The CouchDB image uses several environment variables for configuration:

**Required variables for admin user setup**

- `COUCHDB_USER`: Specifies the admin username for CouchDB. Required for setting up an admin account.
- `COUCHDB_PASSWORD`: Sets the password for the admin user. This variable is required when `COUCHDB_USER` is set.

**Optional variables**

- `COUCHDB_SECRET`: Sets the secret token for Proxy and Cookie Authentication. If not specified, a random UUID will be
  generated.
- `NODENAME`: Sets the name of the CouchDB node. Defaults to `nonode@nohost` for single-node setups, but should be set
  to a proper value for clustered deployments.

**Container configuration**

- The image uses `tini` as the init system for proper signal handling and process reaping
- Data directory: `/opt/couchdb/data` (mounted volumes should target this path)
- Configuration directory: `/opt/couchdb/etc` with `/opt/couchdb/etc/local.d` for custom configs

Example with multiple environment variables:

```bash
docker run --name couchdb-configured -d \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=mypassword \
  -e COUCHDB_SECRET=mysecrettoken \
  -e NODENAME=couchdb@localhost \
  -p 5984:5984 \
  dhi.io/couchdb:<tag>
```

### Using custom configuration files

You can mount custom configuration files to customize CouchDB behavior. Custom configurations should be placed in the
`/opt/couchdb/etc/local.d/` directory:

```bash
docker run --name my-couchdb -d \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=mysecretpassword \
  -v $(pwd)/local.ini:/opt/couchdb/etc/local.d/custom.ini:ro \
  -p 5984:5984 \
  dhi.io/couchdb:<tag>
```

Alternatively, mount an entire configuration directory:

```bash
docker run --name my-couchdb -d \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=mysecretpassword \
  -v $(pwd)/config:/opt/couchdb/etc/local.d:ro \
  -p 5984:5984 \
  dhi.io/couchdb:<tag>
```

### Database backup and replication

CouchDB supports built-in replication. To backup a database, you can replicate it to another CouchDB instance or create
a snapshot:

```bash
# Replicate a database to another CouchDB instance
curl -X POST http://admin:password@localhost:5984/_replicate \
  -H "Content-Type: application/json" \
  -d '{"source":"mydb","target":"http://admin:password@backup-server:5984/mydb"}'
```

For manual backups, you can copy the data directory:

```bash
# Stop the container first
docker stop my-couchdb

# Backup the data volume
docker run --rm -v couchdb-data:/data -v $(pwd):/backup busybox tar czf /backup/couchdb-backup.tar.gz /data

# Restart the container
docker start my-couchdb
```

## CouchDB clustering

CouchDB supports clustering for high availability and horizontal scaling. To set up a cluster, run multiple CouchDB
containers and configure them to join the same cluster.

**Important:** The DHI CouchDB image exposes three ports for full functionality:

- **5984/tcp**: Main CouchDB HTTP API endpoint
- **4369/tcp**: Erlang Port Mapper Daemon (epmd) - required for clustering
- **9100/tcp**: CouchDB cluster communication port

For clustering to work properly, ensure all three ports are accessible between nodes:

```bash
# Create network first
docker network create couchdb-network

# Start first node
docker run --name couchdb1 -d \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=password \
  -e NODENAME=couchdb1@couchdb1 \
  -p 5984:5984 \
  -p 4369:4369 \
  -p 9100:9100 \
  --network couchdb-network \
  dhi.io/couchdb:<tag>

# Start second node
docker run --name couchdb2 -d \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=password \
  -e NODENAME=couchdb2@couchdb2 \
  -p 5985:5984 \
  -p 4370:4369 \
  -p 9101:9100 \
  --network couchdb-network \
  dhi.io/couchdb:<tag>
```

Then use the CouchDB cluster setup API to join the nodes together. See the official CouchDB documentation for detailed
clustering instructions.

## Docker Official Images vs. Docker Hardened Images

### Key differences

| Feature         | Docker Official CouchDB             | Docker Hardened CouchDB                             |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as couchdb (root) user         | Runs as nonroot user (couchdb, uid 65532)           |
| Attack surface  | Larger due to additional utilities  | Minimal, only contains essential components         |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

## Why no package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a package manager nor any tools for debugging. Common debugging
methods for applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

For example, you can use Docker Debug:

```bash
docker debug my-couchdb
```

This provides an interactive debugging shell with access to the container's process namespace.

## Image variants

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

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. Docker Hardened CouchDB images include FIPS-compliant variants for environments requiring
Federal Information Processing Standards compliance.

#### Runtime requirements specific to FIPS:

- FIPS mode enforces stricter cryptographic standards
- Weak cryptographic functions like MD5 are disabled and will fail at runtime
- Applications using restricted algorithms may need modification
- Only FIPS-approved cryptographic algorithms are available

**FIPS Implementation Details:**

The FIPS-compliant CouchDB images are configured with:

- Erlang VM argument: `-crypto fips_mode true` in `/opt/couchdb/etc/vm.args`
- System config: `{crypto, [{fips_mode, true}]}` in `sys.config`
- These settings enable FIPS 140-validated cryptographic operations in the Erlang runtime

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| Data directory     | DHI CouchDB uses `/opt/couchdb/data` for data storage. Ensure volume mounts and backup scripts use the correct path.                                                                                                                                                                                                         |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. **Install additional packages**.

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

1. **Update volume mounts for data directory**.

   Update any volume mounts to use the correct CouchDB data directory.

   For `docker run` commands:

   ```bash
   docker run -v couchdb-data:/opt/couchdb/data dhi.io/couchdb:<tag>
   ```

   For `docker-compose.yml`:

   ```yaml
   volumes:
     - couchdb-data:/opt/couchdb/data
   ```

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain any tools for debugging. The recommended method for debugging
applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

For CouchDB-specific debugging, you can access the built-in HTTP API for monitoring:

```bash
# Check server status
curl http://admin:password@localhost:5984/_up

# View active tasks
curl http://admin:password@localhost:5984/_active_tasks

# Check node information
curl http://admin:password@localhost:5984/_node/_local/_stats
```

Check CouchDB logs:

```bash
docker logs my-couchdb
```

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

For CouchDB, the data directory and configuration files must have appropriate ownership. The image handles this
automatically for the default data location, but custom mounted files may need permission adjustments.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

CouchDB's default port 5984 is not affected by this limitation and works without any special configuration.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

### Data migration from Docker Official Images

When migrating existing CouchDB deployments from Docker Official Images or other CouchDB images, you need to account for
the data directory location. Most CouchDB images use `/opt/couchdb/data`, which is the same path used by DHI.

For new deployments, use the standard path when mounting volumes:

```bash
docker run --name my-couchdb -d \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=password \
  -v couchdb-data:/opt/couchdb/data \
  -p 5984:5984 \
  dhi.io/couchdb:<tag>
```

For existing data migration:

- Option 1: Replication (recommended for production)

  Use CouchDB's built-in replication to migrate data from old to new container:

  ```bash
  # Start new DHI container
  docker run --name new-couchdb -d \
    -e COUCHDB_USER=admin \
    -e COUCHDB_PASSWORD=password \
    -p 5985:5984 \
    dhi.io/couchdb:<tag>

  # Replicate all databases from old to new
  curl -X POST http://admin:password@localhost:5984/_replicate \
    -H "Content-Type: application/json" \
    -d '{"source":"http://admin:password@old-server:5984/dbname","target":"dbname"}'
  ```

- Option 2: Direct data copy

  Stop old container and copy data:

  ```bash
  docker stop old-couchdb

  docker run --rm \
    -v old-couchdb-data:/old \
    -v new-couchdb-data:/new \
    busybox sh -c "cp -a /old/. /new/"

  docker run --name new-couchdb -d \
    -e COUCHDB_USER=admin \
    -e COUCHDB_PASSWORD=password \
    -v new-couchdb-data:/opt/couchdb/data \
    dhi.io/couchdb:<tag>
  ```

If your CouchDB container fails to start or you can't find your data, verify you're using the correct data directory
path (`/opt/couchdb/data`).
