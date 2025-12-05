# dhi/versitygw

## How to use this image

### What's included in this VersityGW Hardened Image

This image contains the following tools:

- `versitygw`: The server used to translate incoming S3 api requests to a existing storage system.

The entry point for the image is `versitygw` and you must specify the command to run.

### Deploy VersityGW into Kubernetes

To use this image in your Kubernetes cluster, replace the standard VersityGW images in your deployment manifests. The
following example shows how to configure a VersityGW server deployment:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: versitygw
spec:
  template:
    spec:
      containers:
      - name: versitygw
        image: <your-namespace>/dhi-versitygw:<tag>
        args:
          - posix
          - /var/vgw
        env:
          - name: ROOT_ACCESS_KEY
            value: demo-root-access-key
          - name: ROOT_SECRET_KEY
            value: demo-root-secret-key
          - name: VGW_PORT
            value: ":8080"
          - name: VGW_HEALTH
            value: /healthz
        ports:
          - containerPort: 8080
            protocol: TCP
        volumeMounts:
          - name: data
            mountPath: /var/vgw
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
        - name: data
          emptyDir:
            sizeLimit: 128Mi
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened VersityGW              | Docker Hardened VersityGW                           |
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

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=<your-namespace>/dhi-busybox,destination=/dbg,ro \
  <your-namespace>/<image-name>:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

## Migrate to a Docker Hardened Image

Switching to the hardened Versity S3 Gateway image does not require any special changes. You can use it as a drop-in
replacement for the standard Versity S3 Gateway (`versity/versitygw`) image in your existing workflows and
configurations. Note that the entry point for the hardened image may differ from the standard image, so ensure that your
commands and arguments are compatible.

### Migration steps

1. Update your image reference. Replace the image reference in your Docker run command or Compose file:
   - From: `versity/versitygw:<tag>`
   - To: `<your-namespace>/dhi-versity/versitygw:<tag>`
1. Specify the command to run `versitygw`. All your existing environment variables, volume mounts, and network settings
   remain the same.

### General migration considerations

While the specific configuration requires no changes, be aware of these general differences in Docker Hardened Images:

| Item            | Migration note                                                         |
| --------------- | ---------------------------------------------------------------------- |
| Shell access    | No shell in runtime variants, use Docker Debug for troubleshooting     |
| Package manager | No package manager in runtime variants                                 |
| Debugging       | Use Docker Debug or Image Mount instead of traditional shell debugging |

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

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
