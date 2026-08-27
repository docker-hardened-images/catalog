## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Getting Started with MongoDB MCP Server

The MongoDB MCP Server enables AI applications to interact with MongoDB databases through the Model Context Protocol,
providing tools for querying collections, discovering schemas, and performing database operations.

### Prerequisites

Before using the MongoDB MCP Server, you'll need:

1. **MongoDB Instance**: A running MongoDB server (local or remote)
1. **Connection String**: MongoDB connection URI
1. **Database Access**: Appropriate permissions for the operations you want to perform

### Configuration

#### Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "mongodb": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "MONGODB_URI=mongodb://user:password@host:27017/database",
        "dhi.io/mongodb-mcp"
      ]
    }
  }
}
```

Update the MongoDB URI with your connection details.

#### Environment Variables

The server requires the following environment variables:

- `MONGODB_URI` (required): MongoDB connection string
- `MDB_MCP_LOGGERS` (optional): Comma-separated list of loggers to enable for debugging

### Running the Server

Basic connection:

```bash
docker run --rm -i \
  -e MONGODB_URI=mongodb://localhost:27017/mydb \
  dhi.io/mongodb-mcp
```

With authentication:

```bash
docker run --rm -i \
  -e MONGODB_URI=mongodb://user:password@host:27017/mydb?authSource=admin \
  dhi.io/mongodb-mcp
```

With MongoDB Atlas:

```bash
docker run --rm -i \
  -e MONGODB_URI=mongodb+srv://user:password@cluster.mongodb.net/mydb \
  dhi.io/mongodb-mcp
```

### Connection String Formats

**Local MongoDB:**

```
mongodb://localhost:27017/database
```

**Authenticated MongoDB:**

```
mongodb://username:password@host:27017/database?authSource=admin
```

**MongoDB Atlas:**

```
mongodb+srv://username:password@cluster.mongodb.net/database
```

**Replica Set:**

```
mongodb://host1:27017,host2:27017,host3:27017/database?replicaSet=rs0
```

### Available Tools

The MongoDB MCP Server provides comprehensive database operations:

**Schema Discovery:**

- Inspect collection schemas
- List all collections in database
- Get collection statistics
- Analyze document structure

**Query Operations:**

- Find documents with filters
- Aggregate data with pipelines
- Count documents
- Perform complex queries

**Data Manipulation:**

- Insert documents
- Update documents
- Delete documents
- Bulk operations

**Index Management:**

- List indexes on collections
- View index statistics
- Analyze query performance

### Example Use Cases

**Data Exploration**

```
Query: "What collections exist in the database?"
Server lists all collections with their document counts
```

**Schema Analysis**

```
Query: "What fields are in the users collection?"
Server analyzes and returns the schema structure
```

**Data Queries**

```
Query: "Find all active users created in the last month"
Server executes query and returns matching documents
```

**Aggregations**

```
Query: "Calculate total sales by product category"
Server runs aggregation pipeline and returns results
```

**Data Updates**

```
Query: "Update the status to 'active' for user with email user@example.com"
Server performs update operation and confirms success
```

### Security Best Practices

1. **Connection Security**: Use TLS/SSL for database connections
1. **Authentication**: Always use authenticated connections
1. **Least Privilege**: Grant minimal required database permissions
1. **Read-Only Access**: Use read-only credentials when possible
1. **Network Isolation**: Restrict database access to trusted networks
1. **Connection Strings**: Secure connection strings using environment variables or secrets
1. **Audit Logging**: Enable MongoDB audit logging for sensitive operations

### Read-Only Mode

For safe, read-only database access, create a read-only user:

```javascript
db.createUser({
  user: "readonly",
  pwd: "password",
  roles: [{ role: "read", db: "mydb" }]
})
```

Use the read-only credentials in your connection string:

```bash
docker run --rm -i \
  -e MONGODB_URI=mongodb://readonly:password@host:27017/mydb \
  dhi.io/mongodb-mcp:<tag>
```

### Debug Mode

Enable debug logging to troubleshoot issues:

```bash
docker run --rm -i \
  -e MONGODB_URI=mongodb://host:27017/mydb \
  -e MDB_MCP_LOGGERS=mongodb-mcp,mongodb \
  dhi.io/mongodb-mcp:<tag>
```

### Performance Tips

- Use indexes for frequently queried fields
- Limit result set sizes for large collections
- Use projection to return only needed fields
- Leverage aggregation pipelines for complex queries
- Monitor query performance with explain plans
- Consider connection pooling for high-volume operations

### Connecting to Local MongoDB from Docker

When MongoDB runs on the host machine:

**Linux:**

```bash
docker run --rm -i \
  --network host \
  -e MONGODB_URI=mongodb://localhost:27017/mydb \
  dhi.io/mongodb-mcp
```

**macOS/Windows:**

```bash
docker run --rm -i \
  -e MONGODB_URI=mongodb://host.docker.internal:27017/mydb \
  dhi.io/mongodb-mcp
```

### Common Connection Issues

**Connection Refused:**

- Verify MongoDB is running
- Check network connectivity
- Confirm host and port are correct

**Authentication Failed:**

- Verify username and password
- Check authSource parameter
- Confirm user has appropriate permissions

**TLS/SSL Errors:**

- Ensure TLS is enabled in connection string
- Verify certificate validity
- Check CA certificate configuration

## Additional Resources

- [MongoDB MCP Server Documentation](https://github.com/mongodb-js/mongodb-mcp-server)
- [MongoDB Connection Strings](https://www.mongodb.com/docs/manual/reference/connection-string/)
- [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
- [Model Context Protocol](https://modelcontextprotocol.io/)

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Argo CD                | Docker Hardened Argo CD                             |
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
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-mongodb-mcp \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/mongodb-mcp:<tag> /dbg/bin/sh
```

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
cryptographic operations.

For example, usage of MD5 fails in FIPS variants. To verify FIPS compliance, check the cryptographic module version in
use by your Argo CD instance.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                       |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                            |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                            |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                           |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                               |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                   |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Argo CD default ports work without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                          |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                          |

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
