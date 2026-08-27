## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a git DHI container

Replace `<tag>` with the image variant you want to run.

```bash
# Check git version
$ docker run --rm dhi.io/git:<tag> --version
```

## Common git DHI use cases

### Clone a repository

```bash
$ docker run --rm -v /tmp/repo:/repo dhi.io/git:<tag> clone --depth 1 https://github.com/example/repo.git /repo
```

### Use as a sidecar in Kubernetes

```yaml
containers:
  - name: git-sidecar
    image: dhi.io/git:<tag>
    command: ["git"]
    args:
      - clone
      - --depth
      - "1"
      - https://example.com/repo.git
      - /data
    volumeMounts:
      - name: shared-data
        mountPath: /data
```

### Multi-stage Dockerfile integration

Use the git DHI image to clone repositories during a build:

```dockerfile
# syntax=docker/dockerfile:1
FROM dhi.io/git:<tag> AS source
RUN git clone --depth 1 https://github.com/example/repo.git /src

FROM dhi.io/alpine-base:3.23
COPY --from=source /src /app
```

## Non-hardened images vs Docker Hardened Images

| Feature             | Standard git images                 | Docker Hardened git                  |
| ------------------- | ----------------------------------- | ------------------------------------ |
| **Security**        | Standard base with common utilities | Hardened base with reduced utilities |
| **Package manager** | Full package managers (apk, apt)    | System package managers removed      |
| **User**            | Runs as root                        | Runs as nonroot user                 |
| **Attack surface**  | Full system utilities available     | Significantly reduced                |
| **Image size**      | ~330 MB (bitnami/git)               | ~21 MB                               |

## Image variants

**Runtime variants** are designed to run git commands in production. These images typically:

- Run as the nonroot user
- Contain only git and essential dependencies (curl, wget)
- Require `docker debug` for any debugging needs

**Dev variants** include `-dev` in the variant name and tag. They are build-time images intended for multi-stage
Dockerfiles. These variants:

- Run as root user
- Include a shell and system package manager (apt)
- Include standard development packages (bash, ca-certificates, coreutils, findutils)
- Should not be used in production

**FIPS variants** include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your git deployment to Docker Hardened Images, you must update your deployment configuration and potentially
your Dockerfile.

| Item                   | Migration note                                              |
| ---------------------- | ----------------------------------------------------------- |
| **Base image**         | Replace standard git images with Docker Hardened git images |
| **Package management** | System package managers removed (apk/apt removed)           |
| **Non-root user**      | Runtime images run as nonroot user                          |
| **File permissions**   | Ensure mounted files are accessible to nonroot user         |

## Troubleshooting migration

### Permissions

By default, runtime image variants run as the nonroot user. Ensure that necessary files and directories are accessible
to the nonroot user. You may need to copy files to different directories or change permissions so your application
running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.
