## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this ricoberger-script-exporter image

This Docker Hardened ricoberger-script-exporter image includes `script_exporter` and the tools the upstream image gives
your scripts: `bash`, `curl`, `jq`, `python3`, `ping`, the core shell utilities (GNU `coreutils`, `grep`, `sed` and
`mawk` on Debian, BusyBox on Alpine) and `tini`, which runs as PID 1 and reaps the processes your scripts leave behind.

In the FIPS variants, `script_exporter` uses the Go FIPS 140-3 module, and `curl` and `python3` use the OpenSSL FIPS
provider, so a script that asks Python for MD5 fails there. Crypto libraries a script brings itself are outside that
boundary.

## Start a ricoberger-script-exporter image

Script Exporter reads `scripts.yaml` from its working directory, `/script_exporter`, unless `--config.files` names
another file. Create a configuration with one script, then start the exporter with both mounted where the upstream image
expects them:

```bash
$ mkdir -p prober/scripts
$ cat > scripts.yaml <<'EOF'
scripts:
  - name: output
    command:
      - ./prober/scripts/output.sh
EOF
$ cat > prober/scripts/output.sh <<'EOF'
#!/usr/bin/env bash
echo '# HELP files_in_tmp Number of entries in /tmp.'
echo '# TYPE files_in_tmp gauge'
echo "files_in_tmp $(ls -A /tmp | wc -l)"
EOF
$ chmod 0755 prober/scripts/output.sh
$ docker run -d --name script_exporter -p 127.0.0.1:9469:9469 \
  -v "$(pwd)/scripts.yaml:/script_exporter/scripts.yaml:ro" \
  -v "$(pwd)/prober/scripts:/script_exporter/prober/scripts:ro" \
  dhi.io/ricoberger-script-exporter:<tag>
$ curl 'http://127.0.0.1:9469/probe?script=output'
```

The exporter's endpoints are unauthenticated by default and the scripts run on every request, so the example binds the
port to the loopback interface. Add TLS and basic authentication, as shown below, before you publish the port on other
interfaces.

The response contains the script's own metrics plus `script_success`, `script_duration_seconds`, `script_exit_code` and
`script_cached` for the script. The exporter also serves its own metrics on `/metrics`, a health check on `/-/healthy`
and the configured scripts as Prometheus HTTP service discovery targets on `/discovery`.

## Common ricoberger-script-exporter use cases

### Scrape scripts with Prometheus

Prometheus calls `/probe` with the script name in the `script` query parameter. Save this as `prometheus.yml` next to
the files from the previous section:

```yaml
scrape_configs:
  - job_name: output
    metrics_path: /probe
    params:
      script:
        - output
    static_configs:
      - targets:
          - script_exporter:9469
  - job_name: script_exporter
    static_configs:
      - targets:
          - script_exporter:9469
```

Then start both services with this `compose.yaml`:

```yaml
services:
  script_exporter:
    image: dhi.io/ricoberger-script-exporter:<tag>
    volumes:
      - ./scripts.yaml:/script_exporter/scripts.yaml:ro
      - ./prober/scripts:/script_exporter/prober/scripts:ro
  prometheus:
    image: dhi.io/prometheus:<tag>
    ports:
      - 127.0.0.1:9090:9090
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    depends_on:
      - script_exporter
```

```bash
$ docker compose up -d
```

Prometheus scrapes each target once a minute by default, so the first `script_success` sample can take up to a minute to
appear. Then query it:

```bash
$ curl -s 'http://127.0.0.1:9090/api/v1/query?query=script_success'
```

### Pass parameters and timeouts to a script

Query parameters reach the script as environment variables. The `params` parameter lists the ones to pass as positional
arguments, in order. When Prometheus sends its scrape timeout, the script sees `SCRIPT_TIMEOUT` (the timeout minus
`--script.timeout-offset`, 0.5 seconds by default) and `SCRIPT_DEADLINE`. Add a script that pings a host given as an
argument:

```bash
$ cat > prober/scripts/ping.sh <<'EOF'
#!/usr/bin/env bash
ping -c 3 "$1" > /dev/null
EOF
$ chmod 0755 prober/scripts/ping.sh
$ cat >> scripts.yaml <<'EOF'
  - name: ping
    command:
      - ./prober/scripts/ping.sh
    output:
      ignore: true
EOF
$ docker restart script_exporter
$ curl 'http://127.0.0.1:9469/probe?script=ping&params=target&target=127.0.0.1'
```

`script_success{script="ping"} 1` reports that `ping` exited zero. The exporter also reloads its configuration on
`SIGHUP`, on a `POST` to `/-/reload` and every `--config.reload-interval` (one hour by default).

### Secure the endpoints with TLS

Pass an
[exporter-toolkit web configuration](https://github.com/prometheus/exporter-toolkit/blob/master/docs/web-configuration.md)
with `--web.config.file`. It applies to `/metrics`, `/probe` and the web UI. The key must be readable by the image's
nonroot user:

```bash
$ mkdir -p tls
$ openssl req -x509 -newkey rsa:3072 -nodes -days 365 -subj /CN=localhost \
  -addext subjectAltName=DNS:localhost -keyout tls/server.key -out tls/server.crt
$ chmod 0644 tls/server.key
$ cat > web.yml <<'EOF'
tls_server_config:
  cert_file: /script_exporter/tls/server.crt
  key_file: /script_exporter/tls/server.key
EOF
$ docker rm -f script_exporter
$ docker run -d --name script_exporter -p 127.0.0.1:9469:9469 \
  -v "$(pwd)/scripts.yaml:/script_exporter/scripts.yaml:ro" \
  -v "$(pwd)/prober/scripts:/script_exporter/prober/scripts:ro" \
  -v "$(pwd)/tls:/script_exporter/tls:ro" \
  -v "$(pwd)/web.yml:/script_exporter/web.yml:ro" \
  dhi.io/ricoberger-script-exporter:<tag> --web.config.file=/script_exporter/web.yml
$ curl --cacert tls/server.crt 'https://localhost:9469/probe?script=output'
```

## Non-hardened images vs. Docker Hardened Images

- The upstream image runs as `nobody` (UID `65534`). This image runs as the nonroot user, UID `65532`. Scripts and
  configuration you mount must be readable, and scripts executable, by that UID.
- The upstream image declares no port. This image declares `9469/tcp`, the exporter's default listen port.
- The upstream image is Alpine-based, so its scripts get BusyBox. The Alpine variants of this image ship BusyBox too.
  The Debian variants ship only GNU `coreutils`, `grep`, `sed`, `mawk` and `iputils-ping` in its place, so the other
  BusyBox applets are absent there, among them `find`, `xargs`, `ps`, `pgrep`, `hostname`, `which`, `tar`, `gzip`,
  `diff`, `wget`, `nc`, `nslookup` and `ip`. Use an Alpine variant for scripts written for the upstream image, or derive
  an image from a `dev` variant to add the tools your scripts need.

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
