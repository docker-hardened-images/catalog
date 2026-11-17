## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This guide provides practical examples for using the ORAS Docker Hardened Image to manage OCI artifacts in registries.

### Running ORAS Commands

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
# Check ORAS version
docker run --rm dhi.io/oras:<tag> version

# Get help for ORAS commands
docker run --rm dhi.io/oras:<tag> --help
```

### Authentication

For operations requiring authentication, mount your Docker configuration:

```bash
# Using Docker credentials
docker run --rm -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/oras:<tag> version

# Using specific credential file
docker run --rm \
  -v /path/to/config.json:/home/nonroot/.docker/config.json:ro \
  dhi.io/oras:<tag> version
```

## Pushing Artifacts

### Push a Single File

```bash
# Create a sample file
echo "Hello, ORAS!" > hello.txt

# Push the file to a registry
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace:ro \
  -w /workspace \
  dhi.io/oras:<tag> push \
    registry.example.com/myrepo/hello:latest hello.txt
```

### Push Multiple Files

```bash
# Push multiple files with media types
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace:ro \
  -w /workspace \
  dhi.io/oras:<tag> push \
    registry.example.com/myrepo/config:v1.0 \
    config.yaml:application/yaml \
    docs.md:text/markdown
```

### Push with Annotations

```bash
# Push with custom annotations
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace:ro \
  -w /workspace \
  dhi.io/oras:<tag> push \
    registry.example.com/myrepo/artifact:latest \
    --annotation "version=1.0" \
    --annotation "environment=production" \
    artifact.tar.gz
```

## Pulling Artifacts

### Pull to Current Directory

```bash
# Pull all files from an artifact
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace \
  -w /workspace \
  dhi.io/oras:<tag> pull \
    registry.example.com/myrepo/hello:latest
```

### Pull Specific Files

```bash
# Pull only specific files
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace \
  -w /workspace \
  dhi.io/oras:<tag> pull \
    registry.example.com/myrepo/config:v1.0 \
    --include "*.yaml"
```

## Copying Artifacts

### Copy Between Registries

```bash
# Copy artifact from one registry to another
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/oras:<tag> copy \
    source-registry.com/myrepo/artifact:v1.0 \
    dest-registry.com/myrepo/artifact:v1.0
```

### Copy with Different Tag

```bash
# Copy and retag
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/oras:<tag> copy \
    registry.example.com/myrepo/app:v1.0 \
    registry.example.com/myrepo/app:latest
```

## Discovery and Inspection

### List Repository Tags

```bash
# List all tags in a repository
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/oras:<tag> repo tags \
    registry.example.com/myrepo/artifact
```

### Discover Related Artifacts

```bash
# Discover artifacts attached to an image
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/oras:<tag> discover \
    registry.example.com/myrepo/app:latest
```

### Show Artifact Manifest

```bash
# Show the manifest of an artifact
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/oras:<tag> manifest fetch \
    registry.example.com/myrepo/artifact:latest
```

## Working with Helm Charts

### Push Helm Chart as OCI Artifact

```bash
# Package and push Helm chart
helm package mychart/
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace:ro \
  -w /workspace \
  dhi.io/oras:<tag> push \
    registry.example.com/myrepo/charts/mychart:1.0.0 \
    mychart-1.0.0.tgz:application/vnd.cncf.helm.chart.content.v1.tar+gzip
```

### Pull Helm Chart

```bash
# Pull Helm chart
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace \
  -w /workspace \
  dhi.io/oras:<tag> pull \
    registry.example.com/myrepo/charts/mychart:1.0.0
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Push Artifact with ORAS
on: [push]

jobs:
  push-artifact:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Login to registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Push artifact
        run: |
          docker run --rm \
            -v ~/.docker:/home/nonroot/.docker:ro \
            -v "${{ github.workspace }}":/workspace:ro \
            -w /workspace \
            dhi.io/oras:<tag> push \
              ghcr.io/${{ github.repository }}/config:${{ github.sha }} \
              config.yaml:application/yaml \
              --annotation "git.sha=${{ github.sha }}" \
              --annotation "git.ref=${{ github.ref }}"
```

### GitLab CI Example

```yaml
push-artifact:
  image: dhi.io/oras:<tag>
  before_script:
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER \
        --password-stdin $CI_REGISTRY
  script:
    - oras push $CI_REGISTRY_IMAGE/config:$CI_COMMIT_SHA
        config.yaml:application/yaml
        --annotation "git.sha=$CI_COMMIT_SHA"
        --annotation "git.ref=$CI_COMMIT_REF_NAME"
```

## Best Practices

1. **Use Specific Tags**: Always use specific version tags rather than `latest` for production workflows.
1. **Include Metadata**: Use annotations to include relevant metadata like version, build information, and provenance.
1. **Secure Credentials**: Use secure credential storage and avoid embedding credentials in images or scripts.
1. **Verify Signatures**: When available, verify artifact signatures before using them in production.
1. **Use Media Types**: Specify appropriate media types for better artifact discovery and tooling compatibility.
1. **Implement Cleanup**: Regularly clean up old or unused artifacts to manage registry storage costs.

## Troubleshooting

### Common Issues

- **Authentication failures**: Ensure Docker credentials are properly mounted and valid
- **Network connectivity**: Check firewall rules and network policies
- **Registry compatibility**: Verify the target registry supports OCI artifacts
- **Permission errors**: Ensure the user has push/pull permissions for the target repository
