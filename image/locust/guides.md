## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/locust:<tag>`
- Mirrored image: `<your-namespace>/dhi-locust:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Locust runs load tests that you write as plain Python files, called locustfiles. The entrypoint is `locust`, so
arguments after the image name are passed to it. The working directory is `/home/locust`. Without `-f`, Locust loads
`locustfile.py` from that directory. The web UI and its REST API listen on port 8089, and a master listens for workers
on port 5557. Locust is documented at <https://docs.locust.io/>.

## Start a Locust image

The examples in this guide use the following locustfile, with an nginx container as the system under test. To test your
own service, set `--host` to its URL.

```bash
$ cat > locustfile.py <<'EOF'
from locust import HttpUser, task, between


class WebsiteUser(HttpUser):
    wait_time = between(1, 2)

    @task
    def index(self):
        self.client.get("/")
EOF
$ docker network create locust-net
$ docker run -d --name target --network locust-net dhi.io/nginx:1
```

### Run a headless test

```bash
$ docker run --rm --network locust-net \
    -v "$PWD/locustfile.py:/home/locust/locustfile.py:ro" \
    dhi.io/locust:<tag> \
    --headless --users 10 --spawn-rate 5 --run-time 30s --host http://target:8080
```

Locust prints request statistics while the test runs, and a summary when the run time ends.

### Run with the web UI

```bash
$ docker run -d --name locust -p 8089:8089 --network locust-net \
    -v "$PWD/locustfile.py:/home/locust/locustfile.py:ro" \
    dhi.io/locust:<tag> --host http://target:8080
```

Open <http://localhost:8089> to start a test and watch its statistics.

## Common Locust use cases

### Write reports to a mounted directory

Runtime variants run as UID 65532. The upstream `locustio/locust` image runs as UID 1000. Mounted locustfiles must be
readable by UID 65532. A directory that `--csv`, `--html`, or `--logfile` writes to must be writable by UID 65532, or
Locust exits with a `PermissionError`.

You can give the output directory to UID 65532:

```bash
$ mkdir -p results
$ sudo chown 65532:65532 results
$ docker run --rm --network locust-net \
    -v "$PWD/locustfile.py:/home/locust/locustfile.py:ro" \
    -v "$PWD/results:/home/locust/results" \
    dhi.io/locust:<tag> \
    --headless --users 10 --spawn-rate 5 --run-time 30s --host http://target:8080 \
    --csv results/run --html results/report.html
```

Or you can run as your own user, as you might have done with the upstream image. `/home/locust` has mode `0700` and is
owned by UID 65532, so other users can't read files mounted inside it. Mount the whole project directory over
`/home/locust` instead:

```bash
$ docker run --rm --network locust-net --user "$(id -u):$(id -g)" \
    -v "$PWD:/home/locust" \
    dhi.io/locust:<tag> \
    --headless --users 10 --spawn-rate 5 --run-time 30s --host http://target:8080 \
    --csv run --html report.html
```

### Use a configuration file

Locust reads `locust.conf` and the `[tool.locust]` table of `pyproject.toml` from the working directory, and
`.locust.conf` from the home directory. Both are `/home/locust`. Pass `--config <path>` to use a file somewhere else.

```bash
$ cat > locust.conf <<'EOF'
headless = true
host = http://target:8080
users = 10
spawn-rate = 5
run-time = 30s
EOF
$ docker run --rm --network locust-net \
    -v "$PWD/locustfile.py:/home/locust/locustfile.py:ro" \
    -v "$PWD/locust.conf:/home/locust/locust.conf:ro" \
    dhi.io/locust:<tag>
```

To use `pyproject.toml`, mount it at `/home/locust/pyproject.toml`:

```toml
[tool.locust]
headless = true
host = "http://target:8080"
users = 10
spawn-rate = 5
run-time = "30s"
```

To use a home directory file, mount it at `/home/locust/.locust.conf`.

### Add Python packages

The runtime variants don't include `pip`. Locust's virtual environment, `/usr/lib/locust`, is owned by root and can't be
changed at runtime. The dev variants include `pip`, and set `PIP_PYTHON` so that `pip install` installs into Locust's
virtual environment:

```dockerfile
FROM dhi.io/locust:<tag>-dev
RUN pip install --no-cache-dir faker
COPY locustfile.py /home/locust/locustfile.py
```

Dev variants run as root. To ship a runtime image that runs as UID 65532, install the packages in a dev stage and copy
the virtual environment into the runtime stage:

```dockerfile
FROM dhi.io/locust:<tag>-dev AS build
RUN pip install --no-cache-dir faker

FROM dhi.io/locust:<tag>
COPY --from=build /usr/lib/locust /usr/lib/locust
COPY locustfile.py /home/locust/locustfile.py
```

Use the same `<tag>` in both stages, for example `2-dev` and `2`, or `2-alpine3.24-dev` and `2-alpine3.24`. The virtual
environment uses the image's own Python, and packages with compiled extensions are built for that distribution.

Build the image and run it. The locustfile is already in the image, so no mount is needed:

```bash
$ docker build -t my-locust .
$ docker run --rm --network locust-net my-locust \
    --headless --users 10 --spawn-rate 5 --run-time 30s --host http://target:8080
```

### Run distributed tests with Docker Compose

A master coordinates the test and serves the web UI. Workers connect to the master on port 5557 and generate the load.
This `compose.yaml` runs one master, two workers, and the nginx target:

```yaml
services:
  target:
    image: dhi.io/nginx:1

  master:
    image: dhi.io/locust:<tag>
    ports:
      - "8089:8089"
    volumes:
      - ./locustfile.py:/home/locust/locustfile.py:ro
    command: --master --host http://target:8080

  worker:
    image: dhi.io/locust:<tag>
    volumes:
      - ./locustfile.py:/home/locust/locustfile.py:ro
    command: --worker --master-host master
    deploy:
      replicas: 2
```

```bash
$ docker compose up -d
$ docker compose logs master
```

The master logs `2 workers connected.` once both workers are ready. Open <http://localhost:8089> to start the test.

Workers on other hosts need to reach the master on port 5557. Publish it with `-p 5557:5557` on the master, and set
`--master-host` on each worker to the master host's address.

### Use a FIPS variant

In FIPS variants, Python's `hashlib` and `ssl` modules use the FIPS-validated OpenSSL provider. HTTPS requests from
`HttpUser` and `FastHttpUser` go through it. Code in a locustfile that uses an unapproved algorithm fails:

```bash
$ docker run --rm --entrypoint python dhi.io/locust:<tag>-fips -c "import hashlib; hashlib.md5(b'x')"
```

The command exits with `_hashlib.UnsupportedDigestmodError: [digital envelope routines] unsupported`.

Traffic between the master and workers on port 5557 uses ZeroMQ and is not encrypted, so it's outside the FIPS boundary.
Keep it on a trusted network.

## Non-hardened images vs. Docker Hardened Images

- Runtime variants run as UID 65532 instead of the upstream UID 1000. See
  [Write reports to a mounted directory](#write-reports-to-a-mounted-directory) for the permissions mounted files and
  output directories need.
- Runtime variants don't include a shell or `pip`, and Locust's virtual environment is read-only at runtime. Add Python
  packages with a dev variant or a multi-stage build, as shown in [Add Python packages](#add-python-packages).
- Dev variants run as root and include a shell, `pip`, and `apt` (Debian) or `apk` (Alpine).

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

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
