## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## About Loki Helm Test

Loki Helm Test is a specialized testing image that contains a compiled Go test binary designed to validate that a Loki
canary is running correctly. This image is primarily used to test Grafana Loki Helm chart deployments by querying
metrics from the Loki canary service.

**Key characteristics:**

- Contains a pre-compiled Go test binary (`helm-test`)
- Tests Loki canary functionality via Prometheus metrics
- Designed for Helm chart validation and CI/CD pipelines
- Requires a running Loki instance with canary enabled
- Can run standalone or as a Kubernetes Job

**Common use cases:**

- Validating Helm chart deployments of Loki
- CI/CD pipeline testing for Loki installations
- Health checks for Loki canary services
- Integration testing with Grafana Loki stacks

## Quick test - List available tests

The image contains a test binary that can list its available tests without requiring a live Loki instance:

```bash
docker run --rm dhi.io/loki-helm-test:<tag> -test.list .
```

Expected output:

```
TestCanary
```

This verifies the image is functional and contains the test binary.

## Running tests against a Loki canary

### Prerequisites for full test execution

To run the complete test suite, you need:

1. A running Loki instance
1. Loki canary service enabled and running
1. Self-monitoring enabled in Loki (canary logs must be stored in Loki)
1. Network connectivity between the test container and Loki

### Run with Docker

If you have a Loki canary running locally:

```bash
docker run --rm \
  --network host \
  dhi.io/loki-helm-test:<tag> \
  -test.v \
  -loki-address=http://localhost:3100
```

With a custom Loki address:

```bash
docker run --rm \
  --network <your-network> \
  dhi.io/loki-helm-test:<tag> \
  -test.v \
  -loki-address=http://loki:3100
```

### Run as a Kubernetes Job

The primary use case for this image is running as a Kubernetes Job to validate Helm chart deployments:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: loki-helm-test
  namespace: monitoring
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: helm-test
          image: dhi.io/loki-helm-test:<tag>
          args:
            - "-test.v"
            - "-loki-address=http://loki-gateway.monitoring.svc.cluster.local"
          env:
            - name: LOKI_ADDRESS
              value: "http://loki-gateway.monitoring.svc.cluster.local"
```

Apply the Job:

```bash
kubectl apply -f loki-helm-test-job.yaml

# Watch the job status
kubectl get jobs -n monitoring -w

# View test results
kubectl logs -n monitoring job/loki-helm-test
```

### Integration with Loki Helm chart

When using the official Grafana Loki Helm chart, this test is available as a Helm test. The chart automatically includes
this test when both conditions are met:

1. Loki canary is enabled
1. Self-monitoring is enabled

To run Helm tests after deployment:

```bash
# Install Loki with canary and self-monitoring
helm install loki grafana/loki \
  --namespace monitoring \
  --create-namespace \
  --set loki.canary.enabled=true \
  --set monitoring.selfMonitoring.enabled=true

# Wait for Loki to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n monitoring --timeout=300s

# Run Helm tests (includes loki-helm-test)
helm test loki -n monitoring

# View test results
kubectl logs -n monitoring -l helm.sh/hook=test
```

## Common test scenarios

### Basic connectivity test

Test that the helm-test binary can reach Loki:

```bash
# Test with verbose output
docker run --rm \
  --network host \
  dhi.io/loki-helm-test:<tag> \
  -test.v \
  -test.run TestCanary \
  -loki-address=http://localhost:3100
```

### CI/CD pipeline integration

Use in a CI pipeline to validate Loki deployments:

```yaml
# Example GitLab CI job
test-loki-deployment:
  stage: test
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker run --rm --network host dhi.io/loki-helm-test:3.6 -test.v -loki-address=http://loki:3100
  only:
    - main
```

### Docker Compose example

Test a Loki stack deployed with Docker Compose:

```yaml
version: '3'

services:
  loki:
    image: dhi.io/loki:3.6
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - loki-net

  loki-canary:
    image: grafana/loki-canary:latest
    command: -addr=loki:3100
    depends_on:
      - loki
    networks:
      - loki-net

  loki-helm-test:
    image: dhi.io/loki-helm-test:3.6
    command: -test.v -loki-address=http://loki:3100
    depends_on:
      - loki
      - loki-canary
    networks:
      - loki-net

networks:
  loki-net:
```

Run the test:

```bash
docker-compose up loki loki-canary -d
sleep 30  # Wait for services to be ready
docker-compose up loki-helm-test
```

## Test arguments and configuration

The helm-test binary accepts standard Go test flags plus Loki-specific arguments:

**Go test flags:**

- `-test.v` - Verbose output
- `-test.run <pattern>` - Run specific tests matching pattern
- `-test.timeout <duration>` - Test timeout (default: 10m)
- `-test.list <pattern>` - List tests without running them

**Loki-specific flags:**

- `-loki-address <url>` - Loki server address (default: http://localhost:3100)

Example with custom timeout:

```bash
docker run --rm \
  --network host \
  dhi.io/loki-helm-test:<tag> \
  -test.v \
  -test.timeout 5m \
  -loki-address=http://localhost:3100
```

## Troubleshooting

### Test fails with connection error

**Symptom:** `connection refused` or `dial tcp` errors

**Solution:**

- Verify Loki is running: `curl http://localhost:3100/ready`
- Check network connectivity between containers
- Ensure correct Loki address is specified

### Test fails with "canary not found"

**Symptom:** Test fails looking for canary metrics

**Solution:**

- Verify Loki canary is running
- Check that canary is logging to the Loki instance
- Verify self-monitoring is enabled in Loki
- Allow time for canary to generate metrics (30-60 seconds)

### Test times out

**Symptom:** Test exceeds timeout before completing

**Solution:**

- Increase test timeout: `-test.timeout 15m`
- Check Loki performance and query response times
- Verify sufficient resources are allocated to Loki

### Cannot list tests

**Symptom:** `-test.list` command fails

**Solution:**

- Verify image version is correct
- Ensure container has execute permissions
- Check container logs for startup errors

## Non-hardened images vs Docker Hardened Images

### Key differences

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official Loki                | Docker Hardened Loki                                |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as user loki (UID 10001)       | Runs as nonroot user (UID 65532)                    |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

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

```bash
docker run --rm -it \
  --pid container:loki \
  --network container:loki-helm-test \
  --cap-add SYS_PTRACE \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/loki:<tag>/dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Runtime variants** are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (UID 65532)
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

**Build-time variants** typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

**FIPS Runtime Requirements:**

- FIPS mode enforces strict cryptographic operations
- MD5 and other non-compliant algorithms will fail
- Ensure your Loki configuration doesn't use deprecated hash algorithms
- TLS/SSL connections use FIPS 140-validated cryptographic modules

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                       |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                            |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                            |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (UID 65532). Note that official Loki images use UID 10001. Ensure that necessary files and directories are accessible to the nonroot user. |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                               |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                   |
| Ports              | Non-dev hardened images run as a nonroot user by default. Loki's default port 3100 is above 1024, so it works without issues.                                                                                        |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                          |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                          |

The following steps outline the general migration process:

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

By default image variants intended for runtime, run as the nonroot user (UID 65532). Ensure that necessary files and
directories are accessible to the nonroot user. You may need to copy files to different directories or change
permissions so your application running as the nonroot user can access them.

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
