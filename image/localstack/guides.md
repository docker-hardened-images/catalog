# How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Refer to the LocalStack documentation for configuring LocalStack for your project's needs.

## Start a LocalStack instance

To start a LocalStack instance, run the following command. Replace `<tag>` with the image variant you want to run.

```bash
$ docker run -d -p 4566:4566 -p 5678:5678 -p 4510-4559:4510-4559 dhi.io/localstack:<tag>
```

**Test the LocalStack instance**: Use the health endpoint to verify LocalStack is running:

```bash
$ curl -f http://localhost:4566/_localstack/health
```

**Note**: Some services may require additional initialization time. If a service shows "available" in health check but
connection fails, wait 10-15 seconds and retry.

## Common LocalStack use cases

### Run LocalStack for development

Start LocalStack with specific AWS services enabled:

```bash
$ docker run -d -p 4566:4566 \
    -e SERVICES=s3,sqs,sns,sts,iam,secretsmanager,ssm \
    dhi.io/localstack:<tag>

# Test that services are available
$ curl -f http://localhost:4566/_localstack/health
```

### Run LocalStack with persistence

This example demonstrates how to enable data persistence in LocalStack, which means your AWS service data (S3 buckets,
SQS queues, etc.) will survive container restarts instead of being lost each time. The setup requires creating a Docker
volume (localstack-data) and mounting it to LocalStack's data directory (`/var/lib/localstack`) while setting the
`PERSISTENCE=1` environment variable. This tells LocalStack to save all service data to the mounted volume instead of
keeping it only in memory.

Enable data persistence across container restarts:

```
# create a volume
$ docker volume create localstack-data
$ docker run -d --name ls-persist-test \
    -p 4566:4566 \
    -e PERSISTENCE=1 \
    -v localstack-data:/var/lib/localstack \
    dhi.io/localstack:<tag>

# Step 2: Verify LocalStack is running
$ curl -f http://localhost:4566/_localstack/health

# Create test data
aws --endpoint-url=http://localhost:4566 s3 mb s3://persistence-test-bucket
aws --endpoint-url=http://localhost:4566 s3 cp /etc/hosts s3://persistence-test-bucket/test-file.txt

# Verify data exists
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 s3 ls s3://persistence-test-bucket

# Start new container with same volume
docker run -d --name ls-persist-test2 \
    -p 4566:4566 \
    -e PERSISTENCE=1 \
    -v localstack-data:/var/lib/localstack \
    dhi.io/localstack:<tag>


# Verify data persisted
echo "Data after restart:"
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 s3 ls s3://persistence-test-bucket
```

### Integration testing with multi-stage Dockerfile

**Important**: LocalStack Docker Hardened Images are runtime-only variants. LocalStack DHI does not provide separate dev
variants.

Here's a complete example for integration testing:

```dockerfile
# syntax=docker/dockerfile:1
# Development stage - Use standard LocalStack for testing setup
FROM localstack/localstack AS test-setup

WORKDIR /app

# Install testing tools and dependencies (standard image has package managers)
RUN apt-get update && apt-get install -y curl jq aws-cli

# Copy test scripts and configuration
COPY test-scripts/ ./test-scripts/
COPY localstack-config/ ./config/

# Runtime stage - LocalStack DHI for production deployment
FROM dhi.io/localstack:<tag> AS runtime

WORKDIR /app
COPY --from=test-setup /app/config/ /etc/localstack/

EXPOSE 4566 5678 4510-4559
# Use default LocalStack entrypoint
```

## Non-hardened images vs Docker Hardened Images

| Feature          | Docker Official LocalStack                                    | Docker Hardened LocalStack                                  |
| ---------------- | ------------------------------------------------------------- | ----------------------------------------------------------- |
| Security         | Standard base with common utilities                           | Hardened base with reduced utilities                        |
| Shell access     | Direct shell access (bash)                                    | Basic shell access (sh)                                     |
| Package manager  | Full package managers (apt, pip)                              | System package managers removed (apt removed, pip retained) |
| User             | Runs as root by default                                       | Runs as nonroot user                                        |
| Attack surface   | Full system utilities available                               | Significantly reduced (tested utilities removed)            |
| System utilities | Full system toolchain (ls, cat, id, ps, find, rm all present) | Extremely minimal (ls, cat, id, ps, find, rm all removed)   |
| Variants         | Single variant for all use cases                              | Runtime-only (no dev variants)                              |

## Image variants

Docker Hardened LocalStack images are **runtime-only variants**. Unlike other DHI products (such as Maven), LocalStack
DHI does not provide separate dev variants with additional development tools.

**Runtime variants** are designed to run LocalStack in production. These images are intended to be used either directly
or as the FROM image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Include basic shell with system package managers removed (pip retained for LocalStack functionality)
- Contain only the minimal set of libraries needed to run LocalStack

# Migrate to a Docker Hardened Image

To migrate your LocalStack deployment to Docker Hardened Images, you must update your deployment configuration and
potentially your Dockerfile.

| Item                 | Migration note                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------------- |
| Base image           | Replace LocalStack base images with Docker Hardened LocalStack images                                   |
| Package management   | System package managers removed (apt removed, pip retained for LocalStack functionality)                |
| Service dependencies | Some services (DynamoDB, Lambda) may not work due to missing Java dependencies                          |
| Non-root user        | Runtime images run as nonroot user. Ensure mounted files are accessible to nonroot user                 |
| Multi-stage build    | Use standard LocalStack images for setup stages and LocalStack DHI for final deployment                 |
| TLS certificates     | Standard certificates included (not independently verified)                                             |
| Ports                | Applications run as nonroot user, but LocalStack is pre-configured for correct ports                    |
| Entry point          | Images use localstack-supervisor as ENTRYPOINT (not independently verified)                             |
| System utilities     | Runtime images lack most system utilities (ls, cat, id, ps, find, rm all removed - verified by testing) |

## Migration process

LocalStack DHI has no dev variants, so you cannot use hardened images for all stages. The multi-stage approach with
standard LocalStack for setup is the recommended pattern for complex deployments.

1. **Understand LocalStack DHI variants.** LocalStack DHI provides only runtime variants. There are no dev variants
   available. Tags like `4.8.1-python3.12-debian13` are all runtime variants with the same security hardening.

1. **Update the base image in your Dockerfile.** Update the base image in your application's Dockerfile to the
   LocalStack DHI you found in the previous step.

1. **Use multi-stage builds for custom setups.** Since LocalStack DHI lacks development tools, use standard LocalStack
   for setup stages and LocalStack DHI for the final runtime stage. Standard LocalStack has the package managers and
   utilities needed for installation tasks.

1. **Handle missing system utilities.** LocalStack DHI removes most system utilities for security. If your setup
   requires tools like curl, jq, or package managers, perform those tasks in a setup stage using standard LocalStack,
   then copy the results to the DHI runtime stage.

1. **Test core services** LocalStack DHI works well with Python-based AWS services but may have issues with
   Java-dependent services like DynamoDB or Lambda due to missing system utilities required for Java installation.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

LocalStack DHI runtime images contain basic shell access but lack most system utilities for debugging. Common commands
like `ls`, `cat`, `id`, `ps`, `find`, and `rm` are removed. The recommended method for debugging applications built with
Docker Hardened Images is to use `docker debug` to attach to these containers. Docker Debug provides a shell, common
debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists during the debugging
session.

### Permissions

By default, runtime image variants run as the non-root user. Ensure that necessary files and directories are accessible
to the non-root user. You may need to copy files to different directories or change permissions so LocalStack running as
the nonroot user can access them.

### Privileged ports

LocalStack DHI runs as a non-root user by default. However, LocalStack is pre-configured to use non-privileged ports
(`4566`, `5678`, `4510-4559`), so privileged port binding is not a concern for LocalStack deployments.

### System utilities

LocalStack DHI runtime images lack most system utilities that some services need for initialization. Missing utilities
include `rm`, `cp`, `mv` (file operations), objcopy (from binutils), `tar`, `gzip` (archive utilities), and `id`, `ps`,
`find` (system inspection tools). Since LocalStack DHI has no dev variants, use multi-stage builds with standard
LocalStack for tasks requiring full system utilities, then copy necessary artifacts to the DHI runtime stage.

### Service dependencies

Some LocalStack services require Java runtime or system utilities not available in the minimized image. Services like
DynamoDB and Lambda may fail during initialization with "command not found" errors for utilities like rm or objcopy.
Core services like S3, SQS, SNS, STS, and IAM work reliably in the hardened environment.

### Entry point

LocalStack DHI images use `localstack-supervisor` as the entry point, which may differ from other LocalStack
distributions. Use `docker inspect` to inspect entry points for Docker Hardened Images and update your deployment
configuration if necessary.
