## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Scan a container image for vulnerabilities

The following command scans a container image for vulnerabilities and displays the results in a table format. Replace
`<tag>` with the image variant you want to run.

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest
```

### Scan a filesystem directory

To scan a local directory for vulnerabilities, mount it as a volume:

```
$ docker run --rm -v $(pwd):/workspace dhi.io/grype:<tag> dir:/workspace
```

### Scan an SBOM (Software Bill of Materials)

Grype can scan SBOMs directly. Mount the SBOM file and scan it:

```
$ docker run --rm -v $(pwd)/sbom.json:/sbom.json dhi.io/grype:<tag> sbom:/sbom.json
```

### Advanced scanning options

#### Filter by severity levels

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest --fail-on critical
```

#### Output in different formats

JSON output:

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest -o json
```

SARIF output for CI/CD integration:

```
$ docker run --rm -v $(pwd):/workspace dhi.io/grype:<tag> ubuntu:latest -o sarif > /workspace/grype-report.sarif
```

CycloneDX XML report:

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest -o cyclonedx
```

CycloneDX JSON report:

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest -o cyclonedx-json
```

#### Sort results by different criteria

Sort by severity:

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest --sort-by severity
```

Sort by EPSS (threat) score:

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest --sort-by epss
```

Sort by risk score:

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest --sort-by risk
```

Sort by KEV (Known Exploited Vulnerabilities):

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest --sort-by kev
```

#### Filter by fix availability

Show only vulnerabilities with available fixes:

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest --only-fixed
```

Show only vulnerabilities without fixes:

```
$ docker run --rm dhi.io/grype:<tag> ubuntu:latest --only-notfixed
```

#### Exclude specific paths

Exclude certain file paths from scanning:

```
$ docker run --rm -v $(pwd):/workspace dhi.io/grype:<tag> dir:/workspace --exclude './out/**/*.json' --exclude '/etc'
```

### Using VEX (Vulnerability Exploitability Exchange)

Grype supports VEX documents for filtering false positives and augmenting results:

```
$ docker run --rm -v $(pwd)/my.vex.json:/vex.json dhi.io/grype:<tag> ubuntu:latest --vex /vex.json
```

### Integration with cosign for attestation verification

Verify attestations with SBOM content using cosign:

```bash
# First, verify attestation and extract SBOM
COSIGN_EXPERIMENTAL=1 cosign verify-attestation myimage:latest \
  | jq -r .payload \
  | base64 --decode \
  | jq -r .predicate.Data \
  | docker run --rm -i dhi.io/grype:<tag>
```

### CI/CD Integration

#### Fail builds on high/critical vulnerabilities

Exit with error code if critical or high severity vulnerabilities are found:

```
$ docker run --rm dhi.io/grype:<tag> myapp:latest --fail-on high
```

#### Generate reports in CI pipelines

GitHub Actions example workflow:

```yaml
- name: Scan image with Grype
  run: |
    docker run --rm -v $(pwd):/workspace dhi.io/grype:<tag> \
      myapp:${{ github.sha }} --fail-on critical -o sarif > /workspace/grype-report.sarif
```

#### Custom output templates

Use custom Go templates for specialized reporting:

```
$ docker run --rm -v $(pwd)/custom.tmpl:/template dhi.io/grype:<tag> ubuntu:latest -o template -t /template
```

### Advanced Configuration

#### Using configuration files

Mount a custom Grype configuration file:

```
$ docker run --rm -v $(pwd)/.grype.yaml:/home/nonroot/.grype.yaml dhi.io/grype:<tag> ubuntu:latest
```

Example configuration with ignore rules:

```yaml
ignore:
  - vulnerability: CVE-2008-4318
    fix-state: unknown
  - package:
      type: gem
  - vulnerability: CVE-2023-12345
    package:
      name: libcurl
      version: "1.5.1"
```

#### External data source integration

Enable Maven repository integration for enhanced matching:

```yaml
external-sources:
  enable: true
  maven:
    search-upstream-by-sha1: true
    base-url: https://search.maven.org/solrsearch/select
    rate-limit: 300ms
```

### Performance Optimization

#### Cache vulnerability database

For repeated scans, cache the vulnerability database:

```
$ docker run --rm -v grype-cache:/home/nonroot/.cache/grype dhi.io/grype:<tag> ubuntu:latest
```

**Note:** When using named volumes with nonroot users, you may encounter permission issues. Consider using bind mounts
with proper permissions instead:

```bash
# Create directory with correct permissions
mkdir -p ~/.cache/grype && chmod 755 ~/.cache/grype
# Use bind mount instead of named volume
docker run --rm -v ~/.cache/grype:/home/nonroot/.cache/grype dhi.io/grype:<tag> db update
```

#### Database-only updates

Update just the vulnerability database without scanning:

```
$ docker run --rm -v grype-cache:/home/nonroot/.cache/grype dhi.io/grype:<tag> db update
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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

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
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Production Usage Patterns

### Enterprise Security Workflows

#### Comprehensive vulnerability assessment

```bash
# Full scan with detailed JSON output for analysis
docker run --rm dhi.io/grype:<tag> myapp:latest -o json > vulnerability-report.json

# Risk-prioritized scanning with EPSS scores
docker run --rm dhi.io/grype:<tag> myapp:latest --sort-by epss --fail-on high
```

#### Policy enforcement with ignore rules

Create a `.grype.yaml` configuration for consistent policy application:

```yaml
ignore:
  # Ignore specific CVE with justification
  - vulnerability: CVE-2023-12345
    fix-state: wont-fix

  # Ignore development dependencies
  - package:
      location: "**/node_modules/**"
      type: npm

  # VEX-based ignoring
  - vex-status: not_affected
    vex-justification: vulnerable_code_not_present
```

#### Compliance reporting

```bash
# Generate CycloneDX SBOM with vulnerabilities for compliance
docker run --rm dhi.io/grype:<tag> myapp:latest -o cyclonedx-json > compliance-report.json

# SARIF format for security dashboards
docker run --rm dhi.io/grype:<tag> myapp:latest -o sarif > security-analysis.sarif
```

### DevSecOps Integration

#### Pre-commit scanning

```bash
# Quick scan of local development environment
docker run --rm -v $(pwd):/workspace dhi.io/grype:<tag> dir:/workspace --fail-on medium
```

#### Container registry integration

```bash
# Scan images before promotion to production
docker run --rm dhi.io/grype:<tag> registry.company.com/myapp:candidate --fail-on high
```

#### Kubernetes deployment scanning

```bash
# Scan all images in a Kubernetes manifest
for image in $(kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u); do
  docker run --rm dhi.io/grype:<tag> "$image" --fail-on critical
done
```

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

For Grype specifically, ensure that:

- Volume mounts are readable by the nonroot user (UID 65532)
- Configuration files have appropriate permissions
- Output directories are writable by the nonroot user
- Cache directories (`/home/nonroot/.cache/grype`) are accessible

**Volume permissions for cache directories:**

When using named volumes with nonroot users, Docker creates volumes owned by root, which the nonroot user cannot write
to. Use one of these workarounds:

1. **Use bind mounts with proper permissions** (recommended):

   ```bash
   mkdir -p ~/.cache/grype && chmod 755 ~/.cache/grype
   docker run --rm -v ~/.cache/grype:/home/nonroot/.cache/grype dhi.io/grype:<tag> db update
   ```

1. **Pre-create named volume with correct ownership**:

   ```bash
   docker volume create --driver local grype-cache
   docker run --rm --user root -v grype-cache:/cache chmod 755 /cache
   docker run --rm -v grype-cache:/home/nonroot/.cache/grype dhi.io/grype:<tag> db update
   ```

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

### Grype-specific troubleshooting

#### Database connectivity issues

If Grype fails to download vulnerability databases, ensure network connectivity:

```bash
# Test database update separately
docker run --rm dhi.io/grype:<tag> db update

# Check database status
docker run --rm dhi.io/grype:<tag> db status
```

#### Large image scanning performance

For very large images, consider increasing memory limits:

```bash
# Increase memory for large scans
docker run --rm --memory=4g dhi.io/grype:<tag> huge-image:latest
```

#### False positive management

Use ignore rules and VEX documents to manage false positives systematically:

```bash
# Test ignore rules configuration
docker run --rm -v $(pwd)/.grype.yaml:/home/nonroot/.grype.yaml dhi.io/grype:<tag> ubuntu:latest

# Validate VEX document application
docker run --rm -v $(pwd)/filter.vex.json:/vex.json dhi.io/grype:<tag> ubuntu:latest --vex /vex.json
```

#### Template formatting issues

For custom templates, validate template syntax:

```bash
# Test custom template with simple data
echo '{"matches": []}' | docker run --rm -i -v $(pwd)/template.tmpl:/template dhi.io/grype:<tag> -o template -t /template
```
