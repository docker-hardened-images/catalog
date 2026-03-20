## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Using with KServe InferenceService

The KServe Storage Initializer is typically used automatically by KServe when you specify a model URI in your
InferenceService. The image runs as an init container to download model artifacts before the serving container starts.

#### Example InferenceService with S3 storage:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: sklearn-iris
spec:
  predictor:
    sklearn:
      storageUri: s3://my-bucket/models/sklearn/iris
```

#### Example InferenceService with GCS storage:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: sklearn-iris
spec:
  predictor:
    sklearn:
      storageUri: gs://my-bucket/models/sklearn/iris
```

### Manual Usage

You can also use this image directly to download model artifacts:

```bash
# Download from S3
docker run --rm -v /local/models:/mnt/models \
  dhi/kserve-storage-initializer:0.15.2 \
  s3://my-bucket/models/sklearn/iris /mnt/models

# Download from GCS  
docker run --rm -v /local/models:/mnt/models \
  dhi/kserve-storage-initializer:0.15.2 \
  gs://my-bucket/models/sklearn/iris /mnt/models

# Download from Git repository
docker run --rm -v /local/models:/mnt/models \
  dhi/kserve-storage-initializer:0.15.2 \
  git://github.com/user/model-repo /mnt/models
```

### Supported Storage Backends

- **S3**: `s3://bucket/path`
- **Google Cloud Storage**: `gs://bucket/path`
- **Azure Blob Storage**: `azure://container/path`
- **HDFS**: `hdfs://namenode:port/path`
- **Git**: `git://github.com/user/repo` or `https://github.com/user/repo.git`
- **Local/PVC**: `/path/to/models`

### Authentication

Configure authentication using standard cloud provider methods:

- **AWS**: Use IAM roles, access keys, or instance profiles
- **GCP**: Use service account keys or workload identity
- **Azure**: Use managed identities or service principals

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

To migrate your KServe deployment to use Docker Hardened Images, you need to configure KServe to use the hardened
storage initializer image.

### Using KServe ConfigMap

Edit the KServe configuration to specify the hardened image:

```bash
kubectl patch configmap/inferenceservice-config -n kserve-system --type merge -p '{
  "data": {
    "storageInitializer": "{\"image\":\"dhi/kserve-storage-initializer:0.15.2\",\"memoryRequest\":\"100Mi\",\"memoryLimit\":\"1Gi\",\"cpuRequest\":\"100m\",\"cpuLimit\":\"1\"}"
  }
}'
```

### Migration Notes

| Item           | Migration note                                                                                                                                           |
| :------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image     | Replace the storage initializer image in your KServe configuration with the Docker Hardened Image.                                                       |
| Authentication | Ensure cloud credentials are properly configured using standard cloud provider authentication methods.                                                   |
| Non-root user  | The hardened image runs as the nonroot user. Ensure that storage permissions allow the nonroot user to write to the destination path.                    |
| Entry point    | The hardened image uses `/opt/kserve/storage-initializer-entrypoint` as the entry point. Update any custom configurations that override the entry point. |
| No shell       | The runtime image doesn't contain a shell. Use `dhi def run` or Docker Debug for troubleshooting.                                                        |

## Troubleshooting

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Common Issues

#### Permission denied errors

Ensure the destination directory is writable by the nonroot user (UID 65532):

```bash
# On the host or in init containers
chown -R 65532:65532 /path/to/models
chmod -R 755 /path/to/models
```

#### Authentication failures

- Verify cloud credentials are properly configured
- Check that service accounts have necessary permissions for the storage bucket
- Ensure network policies allow outbound connections to storage services

#### Storage URI format

- Use the correct URI format for your storage backend
- Ensure bucket/container names and paths are correct
- Check that the storage location exists and is accessible
