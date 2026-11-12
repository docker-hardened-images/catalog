## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/gitlab-exporter:<tag>`
- Mirrored image: `<your-namespace>/dhi-gitlab-exporter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a GitLab Exporter instance

GitLab Exporter runs as a long-lived HTTP server on port 9168 and is scraped by Prometheus. The image ships a default
configuration that enables only the backing-service-free `ruby` probe, so the container boots and serves metrics out of
the box:

```bash
$ docker run --rm -p 9168:9168 dhi.io/gitlab-exporter:<tag>
```

Then scrape the Ruby GC probe, which reports the exporter's own garbage-collector statistics:

```bash
$ curl http://localhost:9168/ruby
```

To collect database (PostgreSQL) or Sidekiq (Redis) metrics, mount your own configuration over
`/etc/gitlab-exporter/gitlab-exporter.yml`.

## Common GitLab Exporter use cases

### Collect PostgreSQL database metrics

Mount a configuration that enables the database probers and points them at your GitLab deployment's PostgreSQL instance.
The `/database` endpoint then exposes tuple stats, row counts, and other database metrics.

Each key under `probes` becomes an endpoint, and the prober class is resolved from that key unless `class_name` says
otherwise. The database probers live under `Database::`, so they must name their class explicitly. Group several of them
behind one endpoint with `multiple: true`.

`gitlab-exporter.yml`:

```yaml
server:
  name: webrick
  listen_address: 0.0.0.0
  listen_port: 9168
probes:
  database:
    multiple: true
    row_counts:
      class_name: Database::RowCountProber
      methods:
        - probe_db
      opts:
        connection_string: "dbname=gitlabhq_production user=gitlab host=postgres.example.com password=secret"
    tuple_stats:
      class_name: Database::TuplesProber
      methods:
        - probe_db
      opts:
        connection_string: "dbname=gitlabhq_production user=gitlab host=postgres.example.com password=secret"
```

```bash
$ docker run --rm -p 9168:9168 \
    -v "$(pwd)/gitlab-exporter.yml:/etc/gitlab-exporter/gitlab-exporter.yml:ro" \
    dhi.io/gitlab-exporter:<tag>
$ curl http://localhost:9168/database
```

### Collect Sidekiq metrics from Redis

Mount a configuration that enables the `sidekiq` probe and points it at your GitLab deployment's Redis instance. The
`/sidekiq` endpoint then exposes queue sizes, worker counts, retry and dead-set sizes, and job throughput counters.

`gitlab-exporter.yml`:

```yaml
server:
  name: webrick
  listen_address: 0.0.0.0
  listen_port: 9168
probes:
  sidekiq:
    methods:
      - probe_stats
      - probe_queues
      - probe_workers
      - probe_retries
    opts:
      - redis_url: redis://redis.example.com:6379
```

```bash
$ docker run --rm -p 9168:9168 \
    -v "$(pwd)/gitlab-exporter.yml:/etc/gitlab-exporter/gitlab-exporter.yml:ro" \
    dhi.io/gitlab-exporter:<tag>
$ curl http://localhost:9168/sidekiq
```

Note that a probe which cannot reach its backing service still answers `200`, with an empty body. If a scrape returns no
metrics, check the container logs rather than the status code.

### Run a one-shot database probe

The exporter also supports one-shot CLI probes for ad hoc inspection. Override the default command to run `row-counts`
against a database and print the result once, without starting the server:

```bash
$ docker run --rm dhi.io/gitlab-exporter:<tag> \
    row-counts --db-conn "dbname=gitlabhq_production user=gitlab host=postgres.example.com password=secret"
```

As with the HTTP probes, an unreachable database is not reported: the command exits `0` and prints nothing.

### Full GitLab (CNG) deployment

For a complete deployment where the exporter runs alongside the GitLab webservice, Sidekiq, and Gitaly with shared
PostgreSQL and Redis, see the [GitLab Helm chart documentation](https://docs.gitlab.com/charts/) and the
[gitlab-exporter documentation](https://docs.gitlab.com/ee/administration/monitoring/prometheus/gitlab_exporter.html).

This image is designed for standalone use and isn't a direct replacement for the Cloud Native GitLab (CNG) image in the
GitLab Helm chart. The chart mounts `gitlab-exporter.yml.erb` under `/var/opt/gitlab-exporter/templates`, and the CNG
entrypoint renders that template to `/etc/gitlab-exporter/gitlab-exporter.yml` at startup. This image doesn't render ERB
templates; mount a completed YAML configuration at `/etc/gitlab-exporter/gitlab-exporter.yml` instead.

When adapting the GitLab Helm chart to use this image:

- Set the chart's metrics scrape path to an endpoint defined by the completed configuration, such as `/ruby`, or define
  an aggregate `/metrics` probe. The chart defaults to `/metrics`, while this image's bundled configuration defines only
  `/ruby`.
- Replace the chart's `/bin/bash`-based `preStop` command with an equivalent `/bin/sh` command, or remove the hook. This
  image includes `dash` as `/bin/sh` and `pkill`, but it doesn't include Bash.
- Use a chart customization or Helm post-renderer to mount the completed configuration and adjust the lifecycle hook;
  the chart's default template mount and hook aren't compatible with this image as shipped.

## Non-hardened images vs. Docker Hardened Images

This image's entrypoint is `/usr/local/bin/gitlab-exporter` and its default command is
`web -c /etc/gitlab-exporter/gitlab-exporter.yml`. The upstream Cloud Native GitLab image instead starts through a
shared entrypoint that renders configuration templates before invoking `process-wrapper`; this image instead ships a
ready-to-serve standalone configuration. Override the command (for example with `row-counts`) to run the one-shot
probes.

Unlike most runtime variants, this image's runtime variants include a shell (`dash`), because the image entrypoint is a
shell script.

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
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                                                                                                             |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step.

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

   For Debian-based images, you can use `apt-get` to install packages.

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
the host.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
