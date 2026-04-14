## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Generate an SBOM for a container image

The following command generates a Software Bill of Materials for a container image and displays it in table format.
Replace `<tag>` with the image variant you want to run.

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest
```

### Generate an SBOM for a filesystem directory

To generate an SBOM for a local directory, mount it as a volume:

```
$ docker run --rm -v $(pwd):/workspace dhi.io/syft:<tag> dir:/workspace
```

### Generate an SBOM for an archive

Syft can analyze compressed archives directly:

```
$ docker run --rm -v $(pwd)/app.tar.gz:/app.tar.gz dhi.io/syft:<tag> /app.tar.gz
```

### Output formats

#### JSON format (Syft native)

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest -o syft-json
```

#### CycloneDX formats

CycloneDX XML (v1.6):

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest -o cyclonedx-xml
```

CycloneDX JSON (v1.6):

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest -o cyclonedx-json
```

CycloneDX XML (v1.5):

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest -o cyclonedx-xml@1.5
```

#### SPDX formats

SPDX tag-value (v2.3):

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest -o spdx-tag-value
```

SPDX JSON (v2.3):

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest -o spdx-json
```

SPDX tag-value (v2.2):

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest -o spdx-tag-value@2.2
```

#### GitHub dependency format

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest -o github-json
```

#### Human-readable text format

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest -o syft-text
```

### Advanced scanning options

#### Include all layers

By default, Syft analyzes the squashed image. To include packages from all layers:

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest --scope all-layers
```

#### Select specific catalogers

Control which package detection methods to use:

```
# Only analyze system packages
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest --catalogers dpkg,rpm,apk

# Focus on language ecosystems
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest --catalogers go-mod-file,npm-package-json,python-pip-requirements
```

#### Exclude file paths

Exclude certain paths from analysis:

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest --exclude './tests/**' --exclude '**/node_modules/**'
```

#### Select catalogers by platform

Only run catalogers appropriate for detected platforms:

```
$ docker run --rm dhi.io/syft:<tag> ubuntu:latest --platform-catalogers
```

### SBOM Attestation with cosign

#### Generate and sign SBOM attestation

First, generate SBOM and pipe to cosign for attestation:

```bash
# Generate SBOM and create signed attestation
docker run --rm dhi.io/syft:<tag> myapp:latest -o spdx-json | \
cosign attest --predicate-type https://spdx.dev/Document --stdin myapp:latest
```

#### Verify SBOM attestation

Extract and verify SBOM from signed attestation:

```bash
# Verify attestation and extract SBOM
COSIGN_EXPERIMENTAL=1 cosign verify-attestation myapp:latest \
  --type https://spdx.dev/Document | jq -r '.payload' | base64 --decode
```

### Format conversion

#### Convert between SBOM formats

Use Syft to convert existing SBOMs between formats:

```bash
# Convert SPDX to CycloneDX
docker run --rm -v $(pwd)/sbom.spdx.json:/input.json -v $(pwd):/output \
  dhi.io/syft:<tag> convert /input.json -o cyclonedx-json > /output/sbom.cyclonedx.json
```

### Custom templates

#### Use Go templates for custom output

```
$ docker run --rm -v $(pwd)/template.tmpl:/template dhi.io/syft:<tag> ubuntu:latest -o template -t /template
```

Example template for CSV output:

```gotemplate
name,version,type
{{- range .Artifacts}}
{{.Name}},{{.Version}},{{.Type}}
{{- end}}
```

### Integration with CI/CD

#### GitHub Actions workflow

```yaml
- name: Generate SBOM
  run: |
    docker run --rm -v $(pwd):/workspace dhi.io/syft:<tag> \
      myapp:${{ github.sha }} -o spdx-json > /workspace/sbom.spdx.json

- name: Upload SBOM artifact
  uses: actions/upload-artifact@v3
  with:
    name: sbom
    path: sbom.spdx.json
```

#### GitLab CI configuration

```yaml
generate-sbom:
  image: dhi.io/syft:<tag>
  script:
    - syft $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -o cyclonedx-json > sbom.json
  artifacts:
    reports:
      cyclonedx: sbom.json
```

### Enterprise workflows

#### Batch SBOM generation

Generate SBOMs for multiple images:

```bash
#!/bin/bash
images=("app:v1.0" "api:v2.1" "worker:v1.5")

for image in "${images[@]}"; do
  echo "Generating SBOM for $image"
  docker run --rm dhi.io/syft:<tag> "$image" -o cyclonedx-json > "sbom-${image//[:\/]/-}.json"
done
```

#### Registry scanning

Scan all images in a registry namespace:

```bash
# List and scan images from registry
registry_url="registry.company.com/myteam"
images=$(docker run --rm dhi.io/syft:<tag> registry:"$registry_url" --catalogers registry)

for image in $images; do
  docker run --rm dhi.io/syft:<tag> "$image" -o spdx-json > "$(basename $image)-sbom.json"
done
```

#### Compliance reporting

Generate compliance-ready SBOMs with comprehensive metadata:

```bash
# Generate detailed SPDX SBOM with all metadata
docker run --rm dhi.io/syft:<tag> myapp:latest \
  -o spdx-json \
  --scope all-layers \
  --select-catalogers \
  --name "MyApp v1.0 SBOM" \
  > compliance-sbom.spdx.json
```

### Configuration file usage

#### Using configuration files

Mount a custom configuration file to control Syft behavior:

```
$ docker run --rm -v $(pwd)/.syft.yaml:/root/.syft.yaml dhi.io/syft:<tag> ubuntu:latest
```

Example configuration:

```yaml
output:
  - "cyclonedx-json"
  - "spdx-tag-value"

exclude:
  - "./tests/**"
  - "**/node_modules/**"

catalogers:
  enabled:
    - "dpkg-cataloger"
    - "rpm-cataloger"
    - "go-mod-file-cataloger"
    - "npm-package-json-cataloger"

package:
  cataloger:
    enabled: true
    scope: "squashed"

attest:
  key: "cosign.key"
  passphrase-env: "COSIGN_PASSWORD"
```

### Performance optimization

#### Parallel processing

Syft automatically uses parallel processing, but you can control resource usage:

```bash
# Increase memory for large images
docker run --rm --memory=4g dhi.io/syft:<tag> huge-image:latest

# Control CPU usage in Kubernetes
resources:
  limits:
    cpu: "2"
    memory: "4Gi"
  requests:
    cpu: "1"
    memory: "2Gi"
```

#### Selective cataloging for speed

For faster scanning, limit catalogers to what you need:

```bash
# Only scan for system packages (fastest)
docker run --rm dhi.io/syft:<tag> ubuntu:latest --catalogers dpkg,rpm,apk

# Only scan for vulnerabilities-relevant packages
docker run --rm dhi.io/syft:<tag> ubuntu:latest --catalogers dpkg,rpm,go-mod-file,npm-package-json
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

## Production Integration Patterns

### Software Supply Chain Security

#### SBOM-driven vulnerability management

```bash
# Generate SBOM and feed to Grype for vulnerability analysis
docker run --rm dhi.io/syft:<tag> myapp:latest -o syft-json | \
docker run --rm -i dhi.io/grype:<tag>
```

#### License compliance automation

```bash
# Extract license information for compliance review
docker run --rm dhi.io/syft:<tag> myapp:latest -o syft-json | \
jq -r '.artifacts[] | select(.licenses != null) | {name: .name, version: .version, licenses: [.licenses[].value]}'
```

#### Dependency tracking

```bash
# Track dependencies across application lifecycle
docker run --rm dhi.io/syft:<tag> myapp:v1.0 -o cyclonedx-json > v1.0-sbom.json
docker run --rm dhi.io/syft:<tag> myapp:v2.0 -o cyclonedx-json > v2.0-sbom.json

# Compare SBOMs to identify changes
diff <(jq -S '.components[].name' v1.0-sbom.json) <(jq -S '.components[].name' v2.0-sbom.json)
```

### Kubernetes integration

#### Operator-based SBOM generation

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sbom-generator
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: syft
            image: dhi.io/syft:<tag>
            command:
            - /bin/sh
            - -c
            - |
              for image in $(kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u); do
                syft "$image" -o cyclonedx-json > "/sboms/$(echo $image | tr ':/' '--').json"
              done
            volumeMounts:
            - name: sbom-storage
              mountPath: /sboms
          volumes:
          - name: sbom-storage
            persistentVolumeClaim:
              claimName: sbom-pvc
          restartPolicy: OnFailure
```

### Registry integration

#### Harbor integration

```bash
# Generate SBOM and upload to Harbor registry
SBOM=$(docker run --rm dhi.io/syft:<tag> myapp:latest -o spdx-json)
echo "$SBOM" | curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $HARBOR_CREDENTIALS" \
  -d @- \
  "$HARBOR_URL/api/v2.0/projects/$PROJECT/repositories/$REPO/artifacts/$TAG/additions/vulnerabilities"
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

For Syft specifically, ensure that:

- Volume mounts are readable by the nonroot user (UID 65532)
- Configuration files have appropriate permissions
- Output directories are writable by the nonroot user
- Docker socket access (if scanning local images) is properly configured

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

### Syft-specific troubleshooting

#### Docker daemon access

For scanning local images, ensure proper Docker socket access:

```bash
# Mount Docker socket for local image scanning
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock dhi.io/syft:<tag> ubuntu:latest
```

#### Large filesystem scanning

For very large directories, consider memory and performance implications:

```bash
# Increase memory limits for large scans
docker run --rm --memory=8g -v $(pwd):/workspace dhi.io/syft:<tag> dir:/workspace
```

#### Private registry authentication

Configure registry credentials for private image scanning:

```bash
# Use Docker credentials
docker run --rm -v ~/.docker/config.json:/root/.docker/config.json dhi.io/syft:<tag> private.registry.com/myapp:latest

# Use environment variables
docker run --rm -e REGISTRY_USERNAME=user -e REGISTRY_PASSWORD=pass dhi.io/syft:<tag> private.registry.com/myapp:latest
```

#### Cataloger issues

If certain packages aren't detected, verify cataloger selection:

```bash
# List available catalogers
docker run --rm dhi.io/syft:<tag> catalogers

# Enable verbose logging for debugging
docker run --rm dhi.io/syft:<tag> ubuntu:latest -vv
```

#### Template rendering errors

For custom templates, validate template syntax and data structures:

```bash
# Test template with verbose output
docker run --rm -v $(pwd)/template.tmpl:/template dhi.io/syft:<tag> ubuntu:latest -o template -t /template -vv
```
