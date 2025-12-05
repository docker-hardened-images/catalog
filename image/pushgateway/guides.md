## Prerequisites

- Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
  organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
  repository**, and then follow the on-screen instructions.
- To use the code snippets in this guide, replace `<your-namespace>` with your organization's namespace and `<tag>` with
  the image variant you want to run.

## What's included in this pushgateway image

This Docker Hardened pushgateway image includes:

- The `pushgateway` binary (statically built) installed at `/bin/pushgateway`.
- Minimal runtime filesystem prepared for secure execution as a nonroot user.

## Start a pushgateway image

The Pushgateway listens on port 9091 by default. Use the following examples to run the hardened image.

### Basic usage

```bash
$ docker run -d --name pushgateway -p 9091:9091 \
  <your-namespace>/dhi-pushgateway:<tag>
```

To pass command-line flags to the Pushgateway (for example to change the listen address or enable persistence), append
them after the image name:

```bash
$ docker run -d --name pushgateway -p 9091:9091 \
  <your-namespace>/dhi-pushgateway:<tag> --web.listen-address=":9091" --persistence.file=/data/pushgateway.snap
```

### Docker Compose example

```yaml
version: '3.8'
services:
  pushgateway:
    image: <your-namespace>/dhi-pushgateway:<tag>
    container_name: pushgateway
    ports:
      - "9091:9091"
    volumes:
      - ./pushgateway-data:/data
    command:
      - "--web.listen-address=:9091"
      - "--persistence.file=/data/pushgateway.snap"

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    ports:
      - "9090:9090"
```

A minimal prometheus.yml to scrape the Pushgateway:

```yaml
scrape_configs:
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']
```

### Environment / configuration

Pushgateway is configured primarily via command-line flags (not environment variables). The hardened image does not
introduce custom environment variables for configuration. Common flags include:

| Flag                 | Description                                                                | Example                  |
| -------------------- | -------------------------------------------------------------------------- | ------------------------ |
| --web.listen-address | Address and port to listen on                                              | ":9091"                  |
| --persistence.file   | Path to a file where metrics are persisted across restarts                 | "/data/pushgateway.snap" |
| --web.route-prefix   | Prefix at which the web UI and metrics are served (if used behind a proxy) | "/"                      |

You can pass flags directly as arguments to the container (see examples above).

## Common pushgateway use cases

- Basic local testing: run a single container and push metrics from short-lived jobs.

  Push a metric with curl:

  ```bash
  echo "some_metric 3.14" | curl --data-binary @- http://localhost:9091/metrics/job/some_job
  ```

- Persisted Pushgateway: mount a host volume for persistence and pass `--persistence.file` so metrics survive restarts:

  ```bash
  docker run -d --name pushgateway -p 9091:9091 \
    -v /var/lib/pushgateway:/data \
    <your-namespace>/dhi-pushgateway:<tag> --persistence.file=/data/pushgateway.snap
  ```

- Prometheus + Pushgateway in Compose: use the Compose example above and configure Prometheus to scrape the Pushgateway.
  Be sure to set `honor_labels: true` in Prometheus' scrape config to avoid overwritten job/instance labels.

## Example: Pushing metrics from a shell script

A simple shell script that pushes a metric (note the newline at end of each metric line):

```bash
#!/bin/sh
echo "batch_job_success 1" | curl --data-binary @- http://pushgateway:9091/metrics/job/batch_job
```

## Important operational notes

- Pushgateway is intended for service-level, ephemeral, or batch-job metrics. It is not a general aggregation system or
  event store. See the upstream docs for guidance on correct usage: https://github.com/prometheus/pushgateway and
  https://prometheus.io/docs/practices/pushing/.

- The Pushgateway adds `push_time_seconds` and `push_failure_time_seconds` metrics for each metric group. These can be
  useful for alerting on stale or failed pushes.

- The hardened runtime runs the binary as a nonroot user. Avoid binding to privileged ports inside the container
  (\<1024) unless using a dev/runtime image that supports it.

## Image details

- Default listen port: 9091/tcp
- Entrypoint: `/bin/pushgateway`
- Working directory: `/pushgateway`
- Runs as nonroot user (UID 65534)

## Non-hardened images vs. Docker Hardened Images

*Note any key differences for this specific image, not general differences. Any information provided in the below
boilerplate should not be repeated here.*

*Everything below here is boilerplate and should be included verbatim!!!!! Be sure to remove this comment and keep
everything below this comment exactly as is.*

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

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item                                                                                              | Migration note                                                                                                                                               |
| :------------------------------------------------------------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image                                                                                        | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                    |
| Package management                                                                                | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                  |
| Non-root user                                                                                     | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.   |
| Multi-stage build                                                                                 | Utilize images with a `dev` tag for build stages and non-dev images for runtime. To ensure that your final image is as minimal as possible, you should use a |
| multi-stage Dockerfile. While intermediary stages will typically use images tagged as `dev`, your |                                                                                                                                                              |
| final runtime stage should use a non-dev image variant.                                           |                                                                                                                                                              |
