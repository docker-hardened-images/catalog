## How to use this image

All examples use the public image. If you have mirrored the image to your own namespace, replace
`dhi.io/nginx-ldap-auth` with your mirrored reference.

Authenticate before pulling:

```bash
docker login dhi.io
```

### What's included in this nginx-ldap-auth image

This Docker Hardened Image runs the `nginx-ldap-auth-daemon`, a reference LDAP authentication daemon for the NGINX
`auth_request` module. NGINX proxies an internal subrequest to the daemon, which reads LDAP connection parameters from
`X-Ldap-*` request headers and the user's credentials from the `Authorization` header (or a cookie), checks them against
an LDAP server -- OpenLDAP or Microsoft Active Directory -- and returns 200 (allow) or 401 (deny). See the
[upstream README](https://github.com/nginxinc/nginx-ldap-auth) for the full NGINX configuration reference, including the
complete `nginx.conf` example and every supported `X-Ldap-*` header.

### Run the nginx-ldap-auth container

Start the daemon. It listens on port 8888 by default. Only NGINX should be able to reach it -- for local testing, bind
the published port to loopback:

```bash
docker run --rm -p 127.0.0.1:8888:8888 dhi.io/nginx-ldap-auth:<tag>
```

With no `X-Ldap-*` headers or credentials, a request is rejected with a `401` and a Basic authentication challenge --
this confirms the daemon is up and enforcing authentication before any LDAP server is involved:

```bash
curl -i http://localhost:8888/
```

Show the daemon's CLI usage:

```bash
docker run --rm dhi.io/nginx-ldap-auth:<tag> --help
```

### Configure NGINX to use the daemon

Point an `auth_request` location at the daemon and pass LDAP connection details as headers on the subrequest. The
`internal` and `proxy_pass_request_headers off` directives from the
[upstream reference configuration](https://github.com/nginxinc/nginx-ldap-auth/blob/master/nginx-ldap-auth.conf) are
required: without them, clients can reach the auth endpoint directly and inject their own `X-Ldap-*` headers (for
example pointing `X-Ldap-URL` at a server they control), bypassing authentication or disclosing credentials.

```nginx
location = /auth-proxy {
    # Required: only reachable via auth_request subrequests, never by clients.
    internal;

    proxy_pass http://nginx-ldap-auth:8888;
    proxy_pass_request_body off;
    # Required: do not forward client headers; set every daemon parameter
    # explicitly below so clients cannot inject X-Ldap-* values.
    proxy_pass_request_headers off;
    proxy_set_header Content-Length "";

    # Prefer ldaps:// (or X-Ldap-Starttls "true") over plaintext ldap://.
    proxy_set_header X-Ldap-URL     "ldaps://ldap.example.com";
    proxy_set_header X-Ldap-BaseDN  "cn=Users,dc=example,dc=com";
    proxy_set_header X-Ldap-BindDN  "cn=root,dc=example,dc=com";
    proxy_set_header X-Ldap-BindPass "secret";

    # Forward only the client credentials the daemon should see.
    proxy_set_header Authorization $http_authorization;
}

location / {
    auth_request /auth-proxy;
    proxy_pass http://backend;
}
```

The daemon also accepts the same connection parameters as CLI flags (`--host`, `-p`/`--port`, `-u`/`--url`,
`-s`/`--starttls`, `-b` basedn, `-D` binddn, `-w` passwd, `-f`/`--filter`, `-R`/`--realm`, `-c`/`--cookie`) for use
outside of NGINX header injection. For Active Directory, the full set of headers, cookie-based auth, and search filter
templating, see the [upstream README](https://github.com/nginxinc/nginx-ldap-auth#required-mods).

### Security considerations

Upstream documents this daemon as a reference model rather than a production-hardened implementation. Cookie-based
authentication only Base64-encodes the credential payload, which upstream describes as "a very weak form of scrambling"
-- if you use cookie-based auth, apply real encryption in the back-end application rather than relying on the cookie
alone. Use TLS between the daemon and the LDAP server (`ldaps://` or `X-Ldap-Starttls`) rather than plaintext `ldap://`,
never expose port 8888 beyond NGINX, and keep the `internal` / `proxy_pass_request_headers off` directives shown above.

### Differences from linuxserver/ldap-auth

This image packages the upstream [nginxinc/nginx-ldap-auth](https://github.com/nginxinc/nginx-ldap-auth) daemon only.
The features added by the `linuxserver/ldap-auth` wrapper are not included: Fernet-encrypted cookies (`FERNET_KEY`), the
HTTPS listener (`CERTFILE`/`KEYFILE`), the bundled `/ldaplogin` login page, and its environment-variable configuration.
Configure this daemon through CLI flags or the `X-Ldap-*` subrequest headers instead.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
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

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                                                               |
| :----------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container.                                 |
| Entry point        | Upstream defaults to `CMD ["python", "/usr/src/app/nginx-ldap-auth-daemon.py", "--host", "0.0.0.0", "--port", "8888"]` with no entrypoint. This image sets the entrypoint to `/usr/bin/nginx-ldap-auth-daemon`; command overrides must drop the `python /usr/src/app/....py` prefix and pass only daemon flags (see Troubleshooting migration, Entry point). |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                                                  |

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

Upstream has no entrypoint and defaults to
`CMD ["python", "/usr/src/app/nginx-ldap-auth-daemon.py", "--host", "0.0.0.0", "--port", "8888"]`. This hardened image
sets the entrypoint to `/usr/bin/nginx-ldap-auth-daemon` and passes `--host 0.0.0.0 --port 8888` as the default command.

A command override copied from upstream is **not** directly compatible: with the fixed entrypoint, a command of
`python /usr/src/app/nginx-ldap-auth-daemon.py --host 0.0.0.0` would be passed to the daemon as arguments (and the image
ships no `python` on `PATH`). When migrating, either remove the interpreter-and-script prefix and pass only the daemon
flags as the command (`--host`, `--port`, `-u`, ...), or override the entrypoint explicitly with
`/usr/bin/nginx-ldap-auth-daemon`. The compatibility symlink at `/usr/src/app/nginx-ldap-auth-daemon.py` also works when
executed directly (as an entrypoint), just not as an argument to `python`. Use `docker inspect` to confirm the
entrypoint when migrating Dockerfiles or orchestration manifests.
