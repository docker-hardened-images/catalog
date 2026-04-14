## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start an ActiveMQ Artemis instance

To start an ActiveMQ Artemis instance, run the following command. Replace `<tag>` with the image variant you want to
run.

```
docker run -d \
  --name artemis \
  -p 61616:61616 \
  -p 8161:8161 \
  -p 61613:61613 \
  -e ARTEMIS_USER=admin \
  -e ARTEMIS_PASSWORD=admin \
  dhi.io/activemq-artemis:<tag>
```

Jolokia CLI is not included in this ActiveMQ Artemis image for security purposes, even though container logs indicate
the REST API is running for Jolokia. Follow the instructions below to verify that the broker and container are running
securely, without relying on any CLI or API.

### Verify container

This hardened image is extremely minimal and doesn't include any OS-level commands (netstat, ps, cat, find, vi). It also
does not include Artemis CLI tools. Since you can’t run netstat inside the container, check host-side connectivity by
running the following commands.

First, create the following Python file `artemis_test_stomp.py` which will test connectivity to the Artemis broker, as
well as sending/receiving messages.

```python
import stomp
import time

BROKER_HOST = "localhost"
BROKER_PORT = 61613
USERNAME = "admin"
PASSWORD = "admin"
QUEUE_NAME = "/queue/test.queue"

class SimpleListener(stomp.ConnectionListener):
    def on_message(self, frame):
        print(f"✅ Received message: {frame.body}")
        self.message = frame.body

def main():
    conn = stomp.Connection12([(BROKER_HOST, BROKER_PORT)])
    listener = SimpleListener()
    conn.set_listener("", listener)
    conn.connect(USERNAME, PASSWORD, wait=True)
    print("🔗 Connected to Artemis broker")

    # Subscribe before sending
    conn.subscribe(destination=QUEUE_NAME, id=1, ack="auto")

    # Send a test message
    message = "Hello from Python!"
    print(f"📤 Sending message: {message}")
    conn.send(destination=QUEUE_NAME, body=message, content_type="text/plain")

    # Wait for message delivery
    for _ in range(10):
        if hasattr(listener, "message"):
            break
        time.sleep(0.5)
    else:
        print("❌ Timed out waiting for message")

    conn.disconnect()
    print("🔌 Disconnected")

if __name__ == "__main__":
    main()
```

Next, create and activate a virtual environment.

```
python3 -m venv ~/artemis-venv
source ~/artemis-venv/bin/activate
```

Your prompt should now show `(artemis-venv)`. Install `stomp.py` inside the virtual environment with
`python3 -m pip install stomp.py`. Run the script with `python3 artemis_test_stomp.py` and you should see the following
results if everything is working correctly.

```
🔗 Connected to Artemis broker
📤 Sending message: Hello from Python!
✅ Received message: Hello from Python!
🔌 Disconnected
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
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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
