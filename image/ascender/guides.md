## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/ascender:<tag>`
- Mirrored image: `<your-namespace>/dhi-ascender:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start an Ascender image

The image is the Ascender control plane as the upstream `ghcr.io/ctrliq/ascender` image ships it:

- the `awx` Django application in a Python 3.12 virtual environment at `/var/lib/awx/venv/awx`
- the built web UI, collected to `/var/lib/awx/public/static`
- nginx, uwsgi, daphne, supervisord and rsyslogd, with the upstream supervisord configs at `/etc/supervisord_web.conf`,
  `/etc/supervisord_task.conf` and `/etc/supervisord_rsyslog.conf`
- the launch scripts `/usr/bin/launch_awx_web.sh`, `/usr/bin/launch_awx_task.sh` and `/usr/bin/launch_awx_rsyslog.sh`,
  plus `awx-manage`, `awx-python`, `wait-for-migrations` and `stop-supervisor` on `PATH`
- the LDAP and xmlsec libraries the application loads

It does not contain receptor or ansible-core: as upstream, those run in the separate execution environment image
(`ghcr.io/ctrliq/ascender-ee`), which the operator deploys next to the task pod. Project updates run there too; this
image ships `git` because GitPython reads and restores the project checkouts in the task container.

### Basic usage

The [ascender-operator](https://github.com/ctrliq/ascender-operator) is the normal way to run Ascender. It renders the
nginx and Django configuration, deploys PostgreSQL and Valkey, runs the migration job and starts the web, task and
rsyslog containers from this image, passing each role's launch script as the container arguments, as it does for the
upstream image.

Install the operator chart of the same version as the image:

```bash
helm repo add ascender-operator https://ctrliq.github.io/ascender-operator/
helm install ascender-operator ascender-operator/ascender-operator \
  --version <version> --namespace ascender --create-namespace
```

Then point an `AWX` resource at this image:

```yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ascender
  namespace: ascender
spec:
  image: dhi.io/ascender
  image_version: <tag>
  control_plane_ee_image: ghcr.io/ctrliq/ascender-ee:<version>
  image_pull_secrets:
    - <dhi-pull-secret>
```

Replace `<tag>` with the image tag, `<version>` with the Ascender version that tag carries (for example `25.6.3`), and
`<dhi-pull-secret>` with the name of a pull secret for `dhi.io` in the `ascender` namespace: a
`kubernetes.io/dockerconfigjson` secret holding your `dhi.io` credentials, as `kubectl create secret docker-registry`
creates. `control_plane_ee_image` is the execution environment the task pod runs next to this image.

Once the `ascender-web` and `ascender-task` Deployments are ready, check the API from your machine.
`kubectl port-forward` listens on `localhost` only:

```bash
kubectl -n ascender port-forward service/ascender-service 8052:80
curl http://127.0.0.1:8052/api/v2/ping/
```

The answer is a JSON document whose `version` field is the Ascender version of the image.

### Environment variables

| Variable           | Description                                             | Default        | Required |
| ------------------ | ------------------------------------------------------- | -------------- | -------- |
| `AWX_LOGGING_MODE` | log to the container output instead of `/var/log/tower` | `stdout`       | No       |
| `HOME`             | the application state directory, as upstream            | `/var/lib/awx` | No       |
| `LANG`, `LC_ALL`   | the locale, as upstream                                 | `en_US.UTF-8`  | No       |

## Common Ascender use cases

### Restricted security context

The image runs as uid 1000 (user `awx`, primary group 0), the same user as upstream, and the directories the roles write
are owned by uid 1000 and group 0 with mode `0770`, so the image also runs as any other uid in group 0, such as the uid
OpenShift's restricted SCC assigns. With the operator defaults the pods have no `securityContext`, so uid 1000 applies.
Setting `restricted_security_context: true` in the `AWX` spec makes the operator render pods that meet the Kubernetes
restricted Pod Security standard, with `runAsUser: 1000` and `fsGroup: 1000` outside OpenShift:

```yaml
spec:
  image: dhi.io/ascender
  image_version: <tag>
  control_plane_ee_image: ghcr.io/ctrliq/ascender-ee:<version>
  restricted_security_context: true
```

This adds `restricted_security_context: true` to the `spec` of the `AWX` resource from the basic usage example; keep its
`image_pull_secrets` entry.

The operator chart's own `AWX.enabled` template sets `runAsUser: 0` unless `security_context_settings` is given; with
this image, set `security_context_settings` to `runAsUser: 1000` there.

### rsyslog role and log aggregators

The rsyslog container (`launch_awx_rsyslog.sh`) runs `rsyslogd`, which forwards the application's logs to an external
log aggregator when one is configured. Every variant includes rsyslog's HTTP output module (`omhttp`), so a log
aggregator can use the HTTPS protocol, the default for a new log aggregator.

### Running a role without the operator

Each role needs the inputs the operator provides, at the upstream paths:

| Path or variable                   | Content                                                                                                          |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `/etc/tower/settings.py`           | Django settings; the operator template is `roles/installer/templates/configmaps/config.yaml.j2`                  |
| `/etc/tower/conf.d/credentials.py` | `DATABASES` pointing at PostgreSQL 14 or later (the operator deploys 15)                                         |
| `/etc/tower/SECRET_KEY`            | the Django secret key                                                                                            |
| `/etc/nginx/nginx.conf`            | the operator's nginx configuration (web role only)                                                               |
| `/var/run/valkey/valkey.sock`      | a Valkey unix socket shared with a sidecar (`unixsocket /var/run/valkey/valkey.sock`, `port 0`)                  |
| `/etc/receptor/receptor.conf`      | the receptor configuration, writable by group 0 (task role only); the operator template's key is `receptor_conf` |
| `/var/run/receptor/receptor.sock`  | the receptor control socket the execution environment sidecar provides (task role only)                          |
| `/var/lib/awx/projects`            | optional project storage                                                                                         |
| `SUPERVISOR_CONFIG_PATH`           | `/etc/supervisord_<role>.conf`, used when the application restarts its own processes                             |

Run `awx-manage migrate --noinput` once before the first role starts, as the operator's migration job does. The task
role's dispatcher exits at start when `/etc/receptor/receptor.conf` is missing or when no receptor answers on
`/var/run/receptor/receptor.sock`, so the task role needs a running receptor next to it, as the operator's execution
environment sidecar provides. The dispatcher also rewrites `receptor.conf`; the image ships `/etc/receptor` writable by
uid 1000 and group 0 for that.

### Custom certificate authorities

Python HTTP clients in the venv read the CA bundle from `/etc/pki/tls/certs/ca-bundle.crt`, the path the upstream Rocky
Linux image and the operator's `bundle_cacert_secret` flow use. In this image that path resolves through
`/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem` to the OS bundle `/etc/ssl/certs/ca-certificates.crt`. When the
operator mounts its extracted trust store at `/etc/pki/ca-trust/extracted`, the same path resolves to the custom bundle,
as it does upstream. OpenSSL itself keeps reading the OS bundle (the Debian variants set `SSL_CERT_FILE` to it); set
`SSL_CERT_FILE` to `/etc/pki/tls/certs/ca-bundle.crt` if clients that use OpenSSL's default store must trust the custom
authorities too.

## Non-hardened images vs. Docker Hardened Images

- The upstream image is based on Rocky Linux 9; this image is based on Debian 13 or Alpine 3.24. Both start with
  `/usr/local/bin/dumb-init --` and pass the role script through unchanged.
- Upstream installs `dumb-init`, `supervisord`, `supervisorctl`, `wait-for-migrations` and `stop-supervisor` in
  `/usr/local/bin`. This image installs them in `/usr/bin` and keeps each `/usr/local/bin` path as a symlink to it.
- Both images run as uid 1000 with primary group 0. Upstream makes its state directories writable by group 0 and owned
  by root, except `/var/lib/nginx`, which the `nginx` user owns; in this image they are owned by uid 1000 and group 0
  with mode `0770`. Any uid in group 0 can write them, so the pods also run as the uid OpenShift's restricted SCC
  assigns; users outside group 0 have no access to them.
- On OpenShift, Route passthrough is not supported: with `ingress_type: route` and
  `route_tls_termination_mechanism: passthrough` the operator's nginx configuration sets `ssl_ciphers PROFILE=SYSTEM;`,
  a cipher keyword only Red Hat's OpenSSL accepts, so nginx in this image refuses to start. Keep
  `route_tls_termination_mechanism` at its default, `edge`.
- Upstream makes `/etc/passwd` group-writable, and each launch script appends a passwd entry for the current uid when
  that uid is 500 or more. `/etc/passwd` is read-only in this image, so a start as such a uid, uid 1000 included, prints
  `/usr/bin/launch_awx_web.sh: line 4: /etc/passwd: Permission denied` (with that role's script name) and then
  continues. uid 1000 already has the `awx` entry.
- Upstream declares `/var/lib/nginx` and `/var/lib/awx/.local/share/containers` as volumes. This image declares no
  volumes; both directories exist and are writable by uid 1000 and group 0.
- Upstream's Rocky Linux base sets `container=oci` in the environment; this image does not. Ascender reads it only for
  the install type in its analytics data, which then reports `k8s` under Kubernetes instead of `openshift`.
- The upstream image installs the `sudo`, `vim-minimal`, `which`, `unzip`, `rsync`, `acl`, `git-lfs`, `subversion`,
  `krb5-workstation` and PostgreSQL client packages and the `virtualenv` and `build` Python tools. The launch scripts
  and the application in this image do not run them, and this image does not install them. On Alpine, BusyBox still
  provides `vi`, `which` and `unzip`, as well as `wget` and `nc`. The runtime variants have no package manager.
- `/etc/nginx/conf.d` is empty on Debian and absent on Alpine; nginx treats both like the empty directory on Rocky
  Linux, so the operator's `include /etc/nginx/conf.d/*.conf` inside the location block works.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  **Ascender is an exception:** the runtime variants ship `bash`, `sh`, `sed`, `grep`, `awk` and coreutils, plus BusyBox
  on Alpine, because the upstream launch scripts and `wait-for-migrations` are shell scripts, the operator's probes and
  init container run `sh -c`, and the application shells out to `sed`.

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

  For Ascender, the validated module backs the system OpenSSL. Python's `ssl` module, `cryptography` (built against the
  system OpenSSL; AWX encrypts stored credentials with it), `psycopg` through `libpq`, `python-ldap`, `xmlsec` and nginx
  all use the system OpenSSL. Three things follow from that:

  - RADIUS and TACACS+ authentication do not work in the FIPS variants. The `pyrad` and `tacacs_plus` clients compute
    MD5 as part of those protocols, and the validated module refuses MD5.
  - SAML signing with RSA-SHA1 fails in the FIPS variants. The python3-saml defaults, RSA-SHA256 signatures with SHA-256
    digests, work. If you set `SOCIAL_AUTH_SAML_SECURITY_CONFIG`, do not copy the `rsa-sha1` and `sha1` values that the
    settings form shows as its example.
  - `pynacl`, a dependency of PyGithub and autobahn, uses libsodium, which is outside the validated module. Ascender
    calls neither of the functions that use it: PyGithub's repository-secret encryption and autobahn's WAMP signing and
    encryption.

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
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. **Ascender is an exception:** its runtime variants ship `bash` and `sh` for the launch scripts and the operator's probes.                        |

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

**Ascender is an exception:** its runtime variants ship `bash`, so `docker exec -it <container> bash` also works.

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

**Ascender is an exception:** its runtime variants ship `bash`, `sh` and the utilities the launch scripts call, but no
package manager.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
