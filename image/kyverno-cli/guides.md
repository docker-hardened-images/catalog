## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this kyverno-cli Hardened image

This image contains `kyverno-cli`, the official Kyverno CLI tool for managing Kubernetes Native Policy Management. The
entry point for the image is `kyverno-cli` which provides policy creation and validation, resource testing against
policies, policy application and management, and integration with CI/CD pipelines for GitOps workflows.

## Start a kyverno-cli instance

Run the following command and replace `<tag>` with the image variant you want to run.

**Note:** `kyverno-cli` is designed as a CLI tool for policy management and can be used in CI/CD pipelines, local
development, or as part of GitOps workflows.

```bash
docker run --rm -it dhi.io/kyverno-cli:<tag> --help
```

## Common kyverno-cli use cases

### Validate policies and resources

`kyverno-cli` can validate Kyverno policies and test resources against those policies without requiring a Kubernetes
cluster. This is especially useful in CI/CD pipelines for policy validation.

```bash
# Validate a policy file
docker run --rm -v $(pwd):/workspace dhi.io/kyverno-cli:<tag> \
  validate /workspace/my-policy.yaml

# Test a resource against policies (apply command)
docker run --rm -v $(pwd):/workspace dhi.io/kyverno-cli:<tag> \
  apply /workspace/my-policy.yaml --resource /workspace/my-resource.yaml
```

### Available kyverno-cli commands

The kyverno-cli CLI provides several key commands:

```bash
# Main Commands:
# apply     - Apply policies on resources (dry-run validation)
# test      - Run tests from directory (comprehensive test suites)  
# validate  - Validate policies and resources
# create    - Create Kyverno resources
# jp        - JMESPath query testing
# version   - Show version information

# Run policy tests from a test directory
docker run --rm -v $(pwd):/workspace dhi.io/kyverno-cli:<tag> \
  test /workspace/kyverno-tests/

# Test JMESPath expressions (useful for policy development)
docker run --rm -v $(pwd):/workspace dhi.io/kyverno-cli:<tag> \
  jp query 'spec.containers[*].image' --input /workspace/resource.yaml

# Create Kyverno resources
docker run --rm -v $(pwd):/workspace dhi.io/kyverno-cli:<tag> \
  create <resource-type>
```

### Use kyverno-cli in CI/CD pipelines

`kyverno-cli` is commonly used in CI/CD pipelines for policy validation and resource testing. Here's an example GitHub
Actions workflow:

```yaml
name: Policy Validation
on: [push, pull_request]

jobs:
  validate-policies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Validate Kyverno Policies
        run: |
          docker run --rm -v ${{ github.workspace }}:/workspace \
            dhi.io/kyverno-cli:<tag> \
            validate /workspace/policies/

      - name: Test Resources Against Policies
        run: |
          docker run --rm -v ${{ github.workspace }}:/workspace \
            dhi.io/kyverno-cli:<tag> \
            apply /workspace/policies/ --resource /workspace/manifests/

      - name: Run Policy Test Suite
        run: |
          docker run --rm -v ${{ github.workspace }}:/workspace \
            dhi.io/kyverno-cli:<tag> \
            test /workspace/kyverno-tests/
```

### Local policy development and testing

Use `kyverno-cli` for local development and testing of Kyverno policies:

```bash
# Create an alias for easier usage
alias kyverno='docker run --rm -v $(pwd):/workspace dhi.io/kyverno-cli:<tag>'

# Validate policies
kyverno validate my-policy.yaml

# Test JMESPath expressions
kyverno jp query 'spec.containers[0].image' --input my-resource.yaml

# Apply policies to resources
kyverno apply my-policy.yaml --resource my-resource.yaml

# Check version
kyverno version
```

### GitOps integration

Integrate `kyverno-cli` into your GitOps workflows for automated policy validation:

```bash
# Pre-commit hook example
#!/bin/bash
# .git/hooks/pre-commit

echo "Validating Kyverno policies..."
docker run --rm -v $(pwd):/workspace \
  dhi.io/kyverno-cli:<tag> \
  validate /workspace/k8s/policies/

if [ $? -ne 0 ]; then
  echo "Policy validation failed. Commit rejected."
  exit 1
fi

echo "Policy validation passed."
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened kyverno-cli            | Docker Hardened kyverno-cli                         |
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

### Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug dhi.io/kyverno-cli
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/kyverno-cli:<tag> /dbg/bin/sh
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

To migrate your application to a Docker Hardened Image, you must update your Kubernetes manifests or Docker
configurations. At minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This
and a few other common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Kubernetes manifests with a Docker Hardened Image.                                                                                                           |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                     |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                    |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                        |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                            |
| Ports              | Non-dev hardened images run as a nonroot user by default. `kyverno-cli` is a CLI tool and doesn't bind to network ports. Because hardened images run as nonroot, avoid privileged operations. |
| Entry point        | Docker Hardened Images may have different entry points than standard images. The DHI kyverno-cli entry point is `/usr/local/bin/kyverno-cli`.                                                 |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                   |
| Volume mounting    | When using kyverno-cli in containers, ensure proper volume mounting for accessing policy files and resources from the host filesystem.                                                        |

The following steps outline the general migration process.

1. **Find hardened images for your CLI usage.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   The kyverno-cli CLI is typically used in CI/CD pipelines and local development environments.

1. **Update your CI/CD pipeline configurations.**

   Update the image references in your CI/CD scripts, GitHub Actions, or other automation to use the hardened images:

   - From: `kyverno/kyverno-cli:<tag>`
   - To: `dhi.io/kyverno-cli:<tag>`

1. **For custom containers, update the base image in your Dockerfile.**

   If you're building custom images that include kyverno-cli, ensure that your final image uses the hardened kyverno-cli
   as the base. For multi-stage builds, use images tagged as `dev` for build stages and non-dev images for runtime.

1. **Update volume mounting and file access patterns.**

   Ensure your scripts properly mount volumes and access policy files and resources. The kyverno-cli CLI needs access to
   policy files and resource manifests through proper volume mounting.

1. **Test CLI functionality.**

   After migration, verify that policy validation, resource testing, and other CLI operations continue to function
   correctly with the hardened image. Test common workflows like `apply`, `validate`, and `test` commands.

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

`kyverno-cli` requires read access to policy files and resource manifests. Ensure your volume mounts and file
permissions allow the nonroot user to access these files when running in containers.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
