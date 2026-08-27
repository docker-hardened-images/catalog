## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this AWS CLI image

This Docker Hardened AWS CLI image includes the complete AWS CLI toolkit in a minimal, security-hardened package built
on Debian 13:

- **AWS CLI v2.31.1**: Complete AWS Command Line Interface with all service integrations and tools including `aws` and
  `aws_completer`
- **Essential system utilities**: Minimal set of packages including `groff-base` for man pages, `less` for paging, and
  `ncurses` for terminal interaction
- **Cryptographic verification**: AWS CLI binary is cryptographically verified using AWS's official GPG key during build
  process
- **Multi-platform support**: Available for both `linux/amd64` and `linux/arm64` architectures
- **Security hardening**: No shell, no package manager, minimal attack surface with zero known vulnerabilities

The image maintains full AWS CLI functionality while prioritizing security through minimalism and cryptographic
verification of all components.

## Start using AWS CLI

Run the following command to verify the AWS CLI installation:

```bash
docker run --rm dhi.io/awscli:<tag> aws --version
```

This command will print out the version of the AWS CLI being used in the container.

## Common AWS CLI use cases

### Get help and command documentation

For any AWS CLI command, you can run its help command to get help information about the command:

```bash
docker run --rm -it dhi.io/awscli:<tag> aws help
```

Get help for specific services:

```bash
docker run --rm -it dhi.io/awscli:<tag> aws s3 help
```

### Configure AWS credentials

Mount your AWS credentials as environment variables or files.

Using environment variables:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID=your-access-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret-key \
  -e AWS_DEFAULT_REGION=us-west-2 \
  dhi.io/awscli:<tag> aws s3 ls
```

Using AWS credentials file:

```bash
docker run --rm \
  -v ~/.aws:/home/nonroot/.aws:ro \
  dhi.io/awscli:<tag> aws s3 ls
```

### List S3 buckets

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID=your-access-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret-key \
  -e AWS_DEFAULT_REGION=us-west-2 \
  dhi.io/awscli:<tag> aws s3 ls
```

### Upload files to S3

Mount local files and upload them:

```bash
docker run --rm \
  -v $(pwd)/myfile.txt:/tmp/myfile.txt:ro \
  -e AWS_ACCESS_KEY_ID=your-access-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret-key \
  -e AWS_DEFAULT_REGION=us-west-2 \
  dhi.io/awscli:<tag> \
  aws s3 cp /tmp/myfile.txt s3://my-bucket/myfile.txt
```

### Use in CI/CD pipelines

AWS CLI is commonly used in automated deployment pipelines:

```bash
# Example: Deploy to ECS
docker run --rm \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION=us-west-2 \
  dhi.io/awscli:<tag> \
  aws ecs update-service --cluster my-cluster --service my-service --force-new-deployment
```

## Docker Official Images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official AWS CLI             | Docker Hardened AWS CLI                             |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only 34 essential packages                 |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| Base OS         | Various Alpine/Debian versions      | Hardened Debian 13 base                             |
| Image size      | Typically larger                    | Optimized at 49.88 MB                               |
| Vulnerabilities | May contain known CVEs              | Zero known vulnerabilities                          |

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

```bash
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-awscli-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/awscli:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Runtime variants** are designed to run your application in production. The AWS CLI image only provides runtime
variants. These images:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run AWS CLI
- Are tagged without any suffix (e.g., `2.31.1`, `2.31`, `2`)

**Note**: Unlike some other DHI images, AWS CLI does not provide separate dev variants. For building or scripting that
requires shell access, use Docker Debug or create custom images based on the runtime variant.

**FIPS variants** include `fips` in the variant name and tag. These variants use cryptographic modules that have been
validated under FIPS 140, a U.S. government standard for secure cryptographic operations. For example, usage of MD5
fails in FIPS variants. FIPS variants are tagged with the `-fips` suffix (e.g., `1.44.12-fips`, `2.32.29-fips`).

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                       |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                            |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                          |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                           |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                           |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                   |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. AWS CLI typically doesn't bind to ports, so this limitation doesn't affect most use cases. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                          |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                          |
| AWS credentials    | Ensure AWS credentials and configuration files are accessible to the nonroot user when mounting volumes.                                                                                                                                                                                                             |
| File permissions   | When mounting local files for AWS operations (like S3 uploads), ensure files are readable by the nonroot user.                                                                                                                                                                                                       |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   AWS CLI images are available with tags like `2.31.1`, `2.31`, `2`, `2.31.1-debian13`, `2.31-debian13`, `2-debian13`,
   and FIPS variants like `1.44.12-fips`, `2.32.29-fips`.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. Since
   AWS CLI DHI only provides runtime variants, you'll use the same image for both development and production workflows.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you can use a multi-stage build with other DHI images that
   have dev variants for building, and use AWS CLI DHI for runtime AWS operations.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. Since AWS CLI DHI
   only provides runtime variants without package managers, you'll need to use other DHI images with dev variants if you
   need to install additional packages alongside AWS CLI functionality.

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

For AWS CLI specifically:

- AWS credentials files must be readable by the nonroot user
- Input files for S3 uploads or other operations must have proper permissions
- Output directories for downloads must be writable by the nonroot user

### AWS credentials and configuration

When mounting AWS credentials or config files, ensure they're accessible to the nonroot user (UID 65532):

```bash
# Ensure proper permissions for mounted credentials
docker run --rm \
  -v ~/.aws:/home/nonroot/.aws:ro \
  dhi.io/awscli:<tag> aws configure list
```

If you encounter permission errors, you may need to adjust file ownership or use environment variables:

```bash
# Alternative approach using environment variables
docker run --rm \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
  dhi.io/awscli:<tag> aws sts get-caller-identity
```

### File operations

When working with files (uploads, downloads, processing), ensure proper permissions for the nonroot user (UID 65532):

```bash
# For uploads, files must be readable by nonroot user (UID 65532)
docker run --rm \
  -v $(pwd)/upload-file.txt:/tmp/upload-file.txt:ro \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION=us-west-2 \
  dhi.io/awscli:<tag> \
  aws s3 cp /tmp/upload-file.txt s3://my-bucket/
```

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. This typically
doesn't affect AWS CLI usage as it's primarily a client tool that doesn't bind to ports.

### No shell

By default, runtime images don't contain a shell or common utilities like `sleep`. Use Docker Debug to debug containers
that need shell access:

```bash
# Start a container with AWS CLI
docker run -d --name my-awscli dhi.io/awscli:<tag> aws help

# Use Docker Debug for shell access
docker debug my-awscli

# Clean up
docker rm -f my-awscli
```

For automation scripts that need shell capabilities, consider creating a custom image or using an external container
with the necessary tools that can invoke the AWS CLI container.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

For AWS CLI, the entry point defaults to `aws help`, but you can override it as needed:

```bash
# Override default command
docker run --rm dhi.io/awscli:<tag> aws --version

# For custom scripts that need AWS CLI, use Docker Debug or external scripting
docker run -d --name aws-container dhi.io/awscli:<tag> aws help
docker debug aws-container
# Inside debug session: run your custom commands
docker rm -f aws-container
```
