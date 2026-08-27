## How to use this image

This guide provides practical examples for using the regctl Docker Hardened Image to perform registry operations and
manage OCI content.

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Running regctl Commands

```bash
# Check regctl version
docker run --rm dhi.io/regctl:0 version

# Get help for regctl commands
docker run --rm dhi.io/regctl:0 --help
```

### Authentication

For operations requiring authentication, mount your Docker configuration:

```bash
# Using Docker credentials
docker run --rm -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 version

# Using specific credential file
docker run --rm \
  -v /path/to/config.json:/home/nonroot/.docker/config.json:ro \
  dhi.io/regctl:0 version
```

## Image Operations

### Inspecting Images

```bash
# Inspect an image manifest
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image manifest \
    registry.example.com/myapp:latest

# Get image config
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image config \
    registry.example.com/myapp:latest

# Get image digest
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image digest \
    registry.example.com/myapp:latest
```

### Copying Images

```bash
# Copy image between registries
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image copy \
    source-registry.com/myapp:v1.0 \
    dest-registry.com/myapp:v1.0

# Copy with different tag
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image copy \
    registry.example.com/myapp:v1.0 \
    registry.example.com/myapp:latest

# Copy all tags from a repository
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image copy \
    --digest-tags \
    source-registry.com/myapp \
    dest-registry.com/myapp
```

### Image Modification

```bash
# Add annotations to an image
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image mod \
    --annotation "version=1.0" \
    --annotation "build-date=$(date -Iseconds)" \
    registry.example.com/myapp:latest

# Convert Docker format to OCI format
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image mod \
    --format oci \
    registry.example.com/myapp:latest

# Replace base image layers
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image mod \
    --replace registry.example.com/base-old:latest=registry.example.com/base-new:latest \
    registry.example.com/myapp:latest
```

## Repository Operations

### Listing Content

```bash
# List repositories in a registry
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 repo ls registry.example.com

# List tags in a repository
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 tag ls registry.example.com/myapp

# List tags with additional details
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 tag ls \
    --format "{{ .Name }} {{ .Digest }}" \
    registry.example.com/myapp
```

### Cleanup Operations

```bash
# Delete specific tag
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 tag delete \
    registry.example.com/myapp:old-version

# Delete image by digest
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image delete \
    registry.example.com/myapp@sha256:abc123...

# Delete unused manifests (dry run)
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image delete \
    --dry-run \
    registry.example.com/myapp
```

## Multi-platform Operations

### Working with Multi-platform Images

```bash
# Create multi-platform manifest
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 index create \
    registry.example.com/myapp:latest \
    registry.example.com/myapp:linux-amd64 \
    registry.example.com/myapp:linux-arm64

# Inspect multi-platform manifest
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image manifest \
    --platform linux/amd64 \
    registry.example.com/myapp:latest

# Copy specific platform
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 image copy \
    --platform linux/arm64 \
    source-registry.com/myapp:latest \
    dest-registry.com/myapp:arm64
```

## OCI Artifact Operations

### Working with Artifacts

```bash
# Push arbitrary content as artifact
echo "configuration data" | docker run --rm -i \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 artifact put \
    --media-type application/vnd.example.config \
    --subject registry.example.com/myapp:latest \
    registry.example.com/myapp:config

# List artifacts attached to an image
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 artifact ls \
    registry.example.com/myapp:latest

# Get artifact content
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 artifact get \
    registry.example.com/myapp:config
```

## Import/Export Operations

### Working with Local Content

```bash
# Export image to OCI layout
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace \
  -w /workspace \
  dhi.io/regctl:0 image export \
    registry.example.com/myapp:latest \
    myapp-oci-layout

# Import from OCI layout
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace \
  -w /workspace \
  dhi.io/regctl:0 image import \
    myapp-oci-layout \
    registry.example.com/myapp:imported

# Export to Docker tar format
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace \
  -w /workspace \
  dhi.io/regctl:0 image export \
    --format docker \
    registry.example.com/myapp:latest \
    myapp.tar
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Registry Operations with regctl
on: [push]

jobs:
  registry-ops:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Login to registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Copy and retag image
        run: |
          docker run --rm \
            -v ~/.docker:/home/nonroot/.docker:ro \
            dhi.io/regctl:0 image copy \
              ghcr.io/${{ github.repository }}:${{ github.sha }} \
              ghcr.io/${{ github.repository }}:latest

      - name: Add metadata annotations
        run: |
          docker run --rm \
            -v ~/.docker:/home/nonroot/.docker:ro \
            dhi.io/regctl:0 image mod \
              --annotation "git.sha=${{ github.sha }}" \
              --annotation "git.ref=${{ github.ref }}" \
              --annotation "build.date=$(date -Iseconds)" \
              ghcr.io/${{ github.repository }}:latest
```

### GitLab CI Example

```yaml
registry-operations:
  image: dhi.io/regctl:0
  before_script:
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER \
        --password-stdin $CI_REGISTRY
  script:
    - regctl image copy
        $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
        $CI_REGISTRY_IMAGE:latest
    - regctl image mod
        --annotation "git.sha=$CI_COMMIT_SHA"
        --annotation "git.ref=$CI_COMMIT_REF_NAME"
        $CI_REGISTRY_IMAGE:latest
```

## Registry Migration

### Bulk Migration Operations

```bash
# Migrate entire repository
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 repo copy \
    old-registry.com/myapp \
    new-registry.com/myapp

# Migrate with filtering
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 repo copy \
    --filter-tag "v.*" \
    old-registry.com/myapp \
    new-registry.com/myapp

# Verify migration
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 repo verify \
    old-registry.com/myapp \
    new-registry.com/myapp
```

## Advanced Use Cases

### Rate Limit Monitoring

```bash
# Check Docker Hub rate limits
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 repo ratelimit \
    docker.io/library/alpine
```

### Registry Health Checks

```bash
# Test registry connectivity
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 registry ping \
    registry.example.com

# Get registry version information
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  dhi.io/regctl:0 registry version \
    registry.example.com
```

## Best Practices

1. **Use Specific Tags**: Always use specific version tags rather than `latest` for production workflows.
1. **Verify Transfers**: Use digest verification when copying critical images to ensure integrity.
1. **Secure Credentials**: Use secure credential storage and avoid embedding credentials in images or scripts.
1. **Monitor Rate Limits**: Check registry rate limits before performing bulk operations.
1. **Test Operations**: Use dry-run flags when available to verify operations before execution.
1. **Cleanup Regularly**: Implement regular cleanup of unused images and tags to manage storage costs.

## Troubleshooting

### Common Issues

- **Authentication failures**: Ensure Docker credentials are properly mounted and valid
- **Network connectivity**: Check firewall rules and network policies
- **Registry compatibility**: Verify the target registry supports required operations
- **Permission errors**: Ensure the user has appropriate permissions for the target repository
- **Rate limiting**: Check for registry rate limits when operations fail
