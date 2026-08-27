## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Two versions of InfluxDB are available: InfluxDB v2 and InfluxDB v3 Core. They are significantly different. Please refer
to the correct section for the version you are using.

## InfluxDB v3 Core

The OSS Core version of InfluxDB v3 is available with `3-core` tags. Run the following command to start an InfluxDB v3
container:

```
$ docker run -p 8181:8181 dhi.io/influxdb:3-core
```

> [!WARNING]
>
> The above command will start `influxdb3` in
> [Quick-start mode](https://docs.influxdata.com/influxdb3/core/reference/cli/influxdb3/#quick-start-mode). Quick-start
> mode is designed for development and testing environments. For production deployments, use explicit configuration with
> the `serve` subcommand and specify all required parameters as described in the
> [documentation](https://docs.influxdata.com/influxdb3/core/reference/cli/influxdb3/serve/).

### Setting up InfluxDB v3 Core

Here's a complete example using Docker Compose to set up InfluxDB v3, initialize it, and write data:

```yaml
services:
  influxdb3:
    image: dhi.io/influxdb:3-core
    environment:
      INFLUXDB3_DISABLE_AUTHZ: health
    command:
      - serve
      - --node-id
      - node1
    ports:
      - "8181:8181"
    networks:
      - influx

  influxdb3-ready-check:
    image: dhi.io/curl:8
    entrypoint:
      - curl
    command:
      - http://influxdb3:8181/health
    restart: on-failure
    depends_on:
      influxdb3:
        condition: service_started
    networks:
      - influx

  influxdb3-cli:
    image: dhi.io/influxdb:3-core-dev
    environment:
      INFLUXDB3_HOST_URL: http://influxdb3:8181
    entrypoint:
      - bash
      - -xc
    command:
      - |
        apt update
        apt install -y jq

        export INFLUXDB3_AUTH_TOKEN=$(influxdb3 create token --admin --format json | jq -r '.token')

        influxdb3 create database test

        influxdb3 write --database test --precision s \
        'home,room=Living\ Room temp=21.1,hum=35.9,co=0i 1641024000
        home,room=Kitchen temp=21.0,hum=35.9,co=0i 1641024000
        home,room=Living\ Room temp=21.4,hum=35.9,co=0i 1641027600
        home,room=Kitchen temp=23.0,hum=36.2,co=0i 1641027600
        home,room=Living\ Room temp=21.8,hum=36.0,co=0i 1641031200
        home,room=Kitchen temp=22.7,hum=36.1,co=0i 1641031200
        home,room=Living\ Room temp=22.2,hum=36.0,co=0i 1641034800
        home,room=Kitchen temp=22.4,hum=36.0,co=0i 1641034800
        home,room=Living\ Room temp=22.2,hum=35.9,co=0i 1641038400
        home,room=Kitchen temp=22.5,hum=36.0,co=0i 1641038400
        home,room=Living\ Room temp=22.4,hum=36.0,co=0i 1641042000
        home,room=Kitchen temp=22.8,hum=36.5,co=1i 1641042000
        home,room=Living\ Room temp=22.3,hum=36.1,co=0i 1641045600
        home,room=Kitchen temp=22.8,hum=36.3,co=1i 1641045600
        home,room=Living\ Room temp=22.3,hum=36.1,co=1i 1641049200
        home,room=Kitchen temp=22.7,hum=36.2,co=3i 1641049200
        home,room=Living\ Room temp=22.4,hum=36.0,co=4i 1641052800
        home,room=Kitchen temp=22.4,hum=36.0,co=7i 1641052800
        home,room=Living\ Room temp=22.6,hum=35.9,co=5i 1641056400
        home,room=Kitchen temp=22.7,hum=36.0,co=9i 1641056400
        home,room=Living\ Room temp=22.8,hum=36.2,co=9i 1641060000
        home,room=Kitchen temp=23.3,hum=36.9,co=18i 1641060000
        home,room=Living\ Room temp=22.5,hum=36.3,co=14i 1641063600
        home,room=Kitchen temp=23.1,hum=36.6,co=22i 1641063600
        home,room=Living\ Room temp=22.2,hum=36.4,co=17i 1641067200
        home,room=Kitchen temp=22.7,hum=36.5,co=26i 1641067200'

        influxdb3 query --database test "SELECT avg(temp) AS avg_temp FROM home WHERE room = 'Kitchen'"
        influxdb3 query --database test --language=influxql "SELECT MEAN(temp) AS avg_temp FROM home WHERE room = 'Living Room'"
    depends_on:
      influxdb3-ready-check:
        condition: service_completed_successfully
    networks:
      - influx

networks:
  influx:
    driver: bridge
```

This example demonstrates:

- Starting an InfluxDB v3 server with explicit configuration
- Waiting for the server to be ready
- Creating an authentication token
- Creating a database
- Writing sample time-series data
- Querying the data using both SQL and InfluxQL

## InfluxDB v2

Run the following command to start an InfluxDB v2 container:

```
$ docker run -p 8086:8086 dhi.io/influxdb:2
```

### Configuration

InfluxDB requires configuration to run. The default configuration file is located at `/etc/influxdb/config.yaml`. You
can override it by mounting your own configuration file at this location.

```
$ docker run -v /path/to/config.yaml:/etc/influxdb/config.yaml -p 8086:8086 dhi.io/influxdb:<tag>
```

The InfluxDB CLI (available in the dev variant) will look for and update CLI configuration at
`/var/lib/influx-cli/configs`. To use your local configuration, mount it at this location.

```
$ docker run -v /path/to/cli/configs:/var/lib/influx-cli/configs --entrypoint influx dhi.io/influxdb:<tag>-dev config list
```

### Setting up InfluxDB

Here's a complete example using Docker Compose to set up InfluxDB, initialize it, and write data:

```yaml
services:
  influxd:
    image: dhi.io/influxdb:2
    ports:
      - "8086:8086"
    networks:
      - influx

  influxd-ready-check:
    image: dhi.io/curl:8
    entrypoint:
      - curl
    command:
      - http://influxd:8086/ready
    restart: on-failure
    depends_on:
      influxd:
        condition: service_started
    networks:
      - influx

  influx-cli:
    image: dhi.io/influxdb:2-dev
    entrypoint:
      - bash
      - -xc
    command:
      - |
        influx setup --host=http://influxd:8086 --username=admin --password=password --org=myorg --bucket=mybucket --token=mytoken --force
        influx config create --config-name=myconfig --host-url=http://influxd:8086 --org=myorg --token=mytoken --active
        influx write --host=http://influxd:8086 --bucket=mybucket --precision s "
        home,room=Living\ Room temp=21.1,hum=35.9,co=0i 1641024000
        home,room=Kitchen temp=21.0,hum=35.9,co=0i 1641024000
        home,room=Living\ Room temp=21.4,hum=35.9,co=0i 1641027600
        home,room=Kitchen temp=23.0,hum=36.2,co=0i 1641027600
        home,room=Living\ Room temp=21.8,hum=36.0,co=0i 1641031200
        home,room=Kitchen temp=22.7,hum=36.1,co=0i 1641031200
        home,room=Living\ Room temp=22.2,hum=36.0,co=0i 1641034800
        home,room=Kitchen temp=22.4,hum=36.0,co=0i 1641034800
        home,room=Living\ Room temp=22.2,hum=35.9,co=0i 1641038400
        home,room=Kitchen temp=22.5,hum=36.0,co=0i 1641038400
        home,room=Living\ Room temp=22.4,hum=36.0,co=0i 1641042000
        home,room=Kitchen temp=22.8,hum=36.5,co=1i 1641042000
        home,room=Living\ Room temp=22.3,hum=36.1,co=0i 1641045600
        home,room=Kitchen temp=22.8,hum=36.3,co=0i 1641045600
        home,room=Living\ Room temp=22.3,hum=36.1,co=0i 1641049200
        home,room=Kitchen temp=22.7,hum=36.2,co=0i 1641049200
        home,room=Living\ Room temp=22.4,hum=36.0,co=0i 1641052800
        home,room=Kitchen temp=22.4,hum=36.0,co=0i 1641052800
        home,room=Living\ Room temp=22.6,hum=35.9,co=0i 1641056400
        home,room=Kitchen temp=22.7,hum=36.0,co=0i 1641056400
        home,room=Living\ Room temp=22.8,hum=36.2,co=0i 1641060000
        home,room=Kitchen temp=23.3,hum=36.9,co=0i 1641060000
        home,room=Living\ Room temp=22.5,hum=36.3,co=0i 1641063600
        home,room=Kitchen temp=23.1,hum=36.6,co=0i 1641063600
        home,room=Living\ Room temp=22.2,hum=36.4,co=17i 1641067200
        home,room=Kitchen temp=22.7,hum=36.5,co=26i 1641067200
        "
        influx query '
        from(bucket: "mybucket")
            |> range(start: 2022-01-01T14:00:00Z, stop: 2022-01-01T20:00:01Z)
            |> filter(fn: (r) => r._measurement == "home")
            |> filter(fn: (r) => r._field == "temp")
            |> group()
            |> mean()
        '
    depends_on:
      influxd-ready-check:
        condition: service_completed_successfully
    networks:
      - influx

networks:
  influx:
    driver: bridge
```

This example demonstrates:

- Starting an InfluxDB server
- Waiting for the server to be ready
- Setting up initial user, organization, and bucket
- Configuring the CLI tool
- Writing sample time-series data
- Querying the data and calculating the mean temperature

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

### InfluxDB-specific considerations

When migrating InfluxDB configurations, pay attention to:

- **Configuration file paths**: Ensure InfluxDB can read its configuration file at `/etc/influxdb/config.yaml` with
  nonroot permissions
- **Data directories**: InfluxDB writes its database files to `/var/lib/influxdb` by default; ensure this directory is
  writable by the nonroot user
- **Bolt and engine paths**: The bolt-path and engine-path in the configuration file must point to directories writable
  by the nonroot user
- **HTTP API port**: InfluxDB listens on port 8086 by default, which is a non-privileged port and works with the nonroot
  user
- **CLI configurations**: When using the dev variant with the `influx` CLI tool, ensure `/var/lib/influx-cli/` is
  writable for storing CLI configurations

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
