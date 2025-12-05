## How to use this image

This guide provides practical examples for using the Crane Docker Hardened Image to manage OCI artifacts in registries.

### Running Crane Commands

```bash
# Check Crane version
docker run --rm <your-namespace>/dhi-crane:<tag> version

# Get help for Crane commands
docker run --rm <your-namespace>/dhi-crane:<tag> --help
```

### Authentication

For operations requiring authentication, mount your Docker configuration:

```bash
# Using Docker credentials
docker run --rm -v ~/.docker:/home/nonroot/.docker:ro \
  <your-namespace>/dhi-crane:<tag> version

# Using specific credential file
docker run --rm \
  -v /path/to/config.json:/home/nonroot/.docker/config.json:ro \
  <your-namespace>/dhi-crane:<tag> version
```

## Discovery and Inspection

### Getting Manifests

```bash
# Obtain a container image manifest
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  <your-namespace>/dhi-crane:<tag> manifest \
    registry.example.com/myrepo/hello:latest
```

### Checking Config

```bash
# Obtain a container image config file
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  <your-namespace>/dhi-crane:<tag> config \
    registry.example.com/myrepo/hello:latest
```

### Checking Digests

```bash
# Obtains a container image digest
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  <your-namespace>/dhi-crane:<tag> digest \
    registry.example.com/myrepo/hello:latest
```

## Managing Container Images

### Redistributing Container Images

```bash
# Copies efficiently a container image from one registry to another
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  <your-namespace>/dhi-crane:<tag> copy \
    registry.example.com/myrepo/foo:latest registry.example.com/myrepo/bar:latest
```

### Storing Container Images

```bash
# Stores a container image as a tar blob
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace \
  -w /workspace \
  <your-namespace>/dhi-crane:<tag> pull \
    registry.example.com/myrepo/hello:latest hello.tar
```

### Pushing Files

```bash
# Push the file to a registry
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace:ro \
  -w /workspace \
  <your-namespace>/dhi-crane:<tag> push \
    /workspace/hello.tar registry.example.com/myrepo/hello:latest
```

### Flattening Container Images

```bash
# Flattens a container image into another tag
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  -v "$(pwd)":/workspace:ro \
  -w /workspace \
  <your-namespace>/dhi-crane:<tag> flatten \
    registry.example.com/myrepo/hello:latest -t registry.example.com/myrepo/hello:flattened
```

## Discovery and Inspection

### Listing Repositories

```bash
# Lists the repos in a registry
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  <your-namespace>/dhi-crane:<tag> catalog \
    registry.example.com
```

### Listing Repository Tags

```bash
# List all tags in a repository
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  <your-namespace>/dhi-crane:<tag> ls \
    registry.example.com/myrepo/artifact
```

### Validating Container Images

```bash
# Validates that a container image is well-formed
docker run --rm \
  -v ~/.docker:/home/nonroot/.docker:ro \
  <your-namespace>/dhi-crane:<tag> validate \
    --remote registry.example.com/myrepo/app:latest
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Copies Image
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
            <your-namespace>/dhi-crane:<tag> copy \
              ghcr.io/${{ github.repository }}-stage:${{ github.sha }} \
              ghcr.io/${{ github.repository }}-prod:${{ github.sha }}
```

### GitLab CI Example

```yaml
push-artifact:
  image: <your-namespace>/dhi-crane:<tag>
  before_script:
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER \
        --password-stdin $CI_REGISTRY
  script:
    - crane push $CI_REGISTRY_IMAGE-stage:$CI_COMMIT_SHA
        $CI_REGISTRY_IMAGE-prod:$CI_COMMIT_SHA
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
