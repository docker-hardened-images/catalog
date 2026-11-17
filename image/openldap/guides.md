## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this OpenLDAP image

This Docker Hardened OpenLDAP image includes:

- `slapd`: the stand-alone LDAP server and the image entry point, `/usr/local/bin/slapd`, a link to `/usr/sbin/slapd`
- `slapadd`, `slapcat`, `slapindex`, `slapmodify`, `slaptest`, `slappasswd`, `slapacl`, `slapauth`, `slapdn` and
  `slapschema`: the offline server tools
- `ldapsearch`, `ldapadd`, `ldapmodify`, `ldapdelete`, `ldapmodrdn`, `ldappasswd`, `ldapwhoami`, `ldapcompare`,
  `ldapexop`, `ldapurl` and `ldapvc`: the LDAP client tools. `ldapvc` is for servers that implement Verify Credentials,
  which `slapd` does not
- Backends and overlays as loadable modules under `/usr/lib/openldap`, including `back_mdb`, `ppolicy`, `syncprov`,
  `memberof`, `refint`, `accesslog` and the `pw-sha2`, `pw-pbkdf2` and `argon2` password hash modules
- On the 2.6 tags, the `back_sql` (with unixODBC) and `back_perl` backends, which upstream removed in 2.7
- The standard schemas under `/etc/openldap/schema`

## Start an OpenLDAP image

The image runs `slapd` in the foreground as the nonroot user (UID 65532) and reads its configuration from the
`cn=config` directory `/etc/openldap/slapd.d`. It listens on these URLs:

- `ldap://:1389/` for LDAP and StartTLS
- `ldaps://:1636/` for LDAP over TLS, once a certificate is configured
- `ldapi:///`, the socket `/run/openldap/ldapi` that the clients use by default, for local administration with SASL
  EXTERNAL

The entry point `/usr/local/bin/slapd` is a link to `/usr/sbin/slapd`, which stays on the `PATH`, so commands and
configurations that call `slapd` by name, such as `--entrypoint slapd`, work unchanged.

The image ships no default configuration. Seed `/etc/openldap/slapd.d` once with `slapadd` before the first start;
without it `slapd` stops at startup with a non-zero exit status.

`slapd` sizes its connection table from the open files limit. At a limit of 1048576, which Docker Desktop and many
container runtimes set, the server idles at about 700 MiB, and a container with a memory limit of a few hundred MiB is
killed. The examples in this guide set `--ulimit nofile=1024:1024`, where it idles at about 4 MiB; raise the limit only
to serve more concurrent connections. On Kubernetes the limit comes from the node's container runtime, as no pod setting
changes it.

On `dev` tags the container runs as root. Add `--user 65532` to `docker run` and `-u 65532` to `docker exec`, so the
`ldapi` commands map to the identity the configuration grants and the volumes stay readable by the runtime tags.

### Seed the configuration

Save the following as `config.ldif`. It loads the MDB backend, the core schemas and one database for
`dc=example,dc=org`. The configuration database and the directory are administered only through the `ldapi` socket by
the container user, so the configuration holds no password.

```ldif
dn: cn=config
objectClass: olcGlobal
cn: config
olcPidFile: /run/openldap/slapd.pid

dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulePath: /usr/lib/openldap
olcModuleLoad: back_mdb.so

dn: cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

include: file:///etc/openldap/schema/core.ldif
include: file:///etc/openldap/schema/cosine.ldif
include: file:///etc/openldap/schema/inetorgperson.ldif

dn: olcDatabase={0}config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: {0}config
olcAccess: {0}to * by dn.exact=gidNumber=65532+uidNumber=65532,cn=peercred,cn=external,cn=auth manage by * none

dn: olcDatabase={1}mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: {1}mdb
olcSuffix: dc=example,dc=org
olcRootDN: gidNumber=65532+uidNumber=65532,cn=peercred,cn=external,cn=auth
olcDbDirectory: /var/lib/openldap/openldap-data
olcDbMaxSize: 1073741824
olcAccess: {0}to attrs=userPassword by self write by anonymous auth by * none
olcAccess: {1}to * by users read by * none
```

Create the volumes and load the file with `slapadd`:

```console
$ docker volume create openldap-config
$ docker volume create openldap-data
$ docker run --rm --entrypoint slapadd \
  -v "$PWD/config.ldif:/config.ldif:ro" \
  -v openldap-config:/etc/openldap/slapd.d \
  dhi.io/openldap:<tag> -n0 -F /etc/openldap/slapd.d -l /config.ldif
```

### Run the server

```console
$ docker run -d --name openldap \
  --ulimit nofile=1024:1024 \
  -p 127.0.0.1:1389:1389 \
  -v openldap-config:/etc/openldap/slapd.d \
  -v openldap-data:/var/lib/openldap/openldap-data \
  dhi.io/openldap:<tag>
```

The example publishes LDAP on the loopback interface only. Anonymous clients can bind, and the access rules in
`config.ldif` give them nothing beyond the root DSE; publish the port more widely only behind TLS and your own access
rules.

Save the following as `base.ldif` and add it over the `ldapi` socket:

```ldif
dn: dc=example,dc=org
objectClass: dcObject
objectClass: organization
dc: example
o: Example

dn: uid=jdoe,dc=example,dc=org
objectClass: inetOrgPerson
uid: jdoe
cn: John Doe
sn: Doe
```

```console
$ docker exec -i openldap ldapadd -Q -Y EXTERNAL -H ldapi:/// < base.ldif
$ docker exec openldap ldappasswd -Q -Y EXTERNAL -H ldapi:/// -s changeme uid=jdoe,dc=example,dc=org
```

Bind as the user over TCP from inside the container:

```console
$ docker exec openldap ldapwhoami -x -H ldap://localhost:1389 -D uid=jdoe,dc=example,dc=org -w changeme
dn:uid=jdoe,dc=example,dc=org
```

### Docker Compose

```yaml
services:
  openldap:
    image: dhi.io/openldap:<tag>
    ulimits:
      nofile:
        soft: 1024
        hard: 1024
    ports:
      - "127.0.0.1:1389:1389"
    volumes:
      - openldap-config:/etc/openldap/slapd.d
      - openldap-data:/var/lib/openldap/openldap-data

volumes:
  openldap-config:
    external: true
  openldap-data:
    external: true
```

The volumes are the ones created and seeded above.

## Common OpenLDAP use cases

### Change the configuration at runtime

`cn=config` changes made over `ldapi` are written to `/etc/openldap/slapd.d` and survive a restart. For example, load
the `memberof` overlay module:

```console
$ printf 'dn: cn=module{0},cn=config\nchangetype: modify\nadd: olcModuleLoad\nolcModuleLoad: memberof.so\n' | \
  docker exec -i openldap ldapmodify -Q -Y EXTERNAL -H ldapi:///
```

### Enable LDAPS and StartTLS

Mount the certificate and key, readable by UID 65532, and point `cn=config` at them:

```console
$ docker run -d --name openldap \
  --ulimit nofile=1024:1024 \
  -p 127.0.0.1:1636:1636 \
  -v "$PWD/certs:/etc/openldap/certs:ro" \
  -v openldap-config:/etc/openldap/slapd.d \
  -v openldap-data:/var/lib/openldap/openldap-data \
  dhi.io/openldap:<tag>
$ printf 'dn: cn=config\nchangetype: modify\nreplace: olcTLSCertificateFile\nolcTLSCertificateFile: /etc/openldap/certs/tls.crt\n-\nreplace: olcTLSCertificateKeyFile\nolcTLSCertificateKeyFile: /etc/openldap/certs/tls.key\n' | \
  docker exec -i openldap ldapmodify -Q -Y EXTERNAL -H ldapi:///
```

The `ldaps://:1636/` listener accepts TLS connections as soon as the certificate is set, and `ldap://:1389/` accepts
StartTLS.

The certificate paths are saved in the `openldap-config` volume. From then on every run of that volume, including the
read-only and Compose examples, needs the same `certs` mount; without it `slapd` stops at startup.

### Run from a slapd.conf file

To use a static `slapd.conf` instead of `cn=config`, save it as `slapd.conf`. This one serves `dc=example,dc=org` from
the data volume and, like `config.ldif`, gives the container user full access over `ldapi`:

```text
include /etc/openldap/schema/core.schema
pidfile /run/openldap/slapd.pid
modulepath /usr/lib/openldap
moduleload back_mdb.so

database mdb
suffix "dc=example,dc=org"
rootdn "gidNumber=65532+uidNumber=65532,cn=peercred,cn=external,cn=auth"
directory /var/lib/openldap/openldap-data
maxsize 1073741824
```

Mount it and override the command:

```console
$ docker run -d --name openldap \
  --ulimit nofile=1024:1024 \
  -p 127.0.0.1:1389:1389 \
  -v "$PWD/slapd.conf:/etc/openldap/slapd.conf:ro" \
  -v openldap-data:/var/lib/openldap/openldap-data \
  dhi.io/openldap:<tag> \
  -d 256 -f /etc/openldap/slapd.conf -h "ldap://:1389/ ldapi:///"
```

### Run with a read-only root filesystem

`slapd` writes only to the two volumes and to `/run/openldap`, where it keeps its pid file and the `ldapi` socket. Mount
a tmpfs there:

```console
$ docker run -d --name openldap --read-only \
  --ulimit nofile=1024:1024 \
  --tmpfs /run/openldap:uid=65532,gid=65532,mode=0755 \
  -p 127.0.0.1:1389:1389 \
  -v openldap-config:/etc/openldap/slapd.d \
  -v openldap-data:/var/lib/openldap/openldap-data \
  dhi.io/openldap:<tag>
```

### Back up the directory

`slapcat` exports a database while the server runs:

```console
$ docker exec openldap slapcat -F /etc/openldap/slapd.d -b dc=example,dc=org > backup.ldif
```

### Hash passwords on the FIPS tags

`slapd` computes its built-in password schemes, such as the default `{SSHA}` and `{MD5}`, with its own code instead of
OpenSSL, and so do the `pw-sha2` and `argon2` modules. On the FIPS tags those schemes keep working and run outside the
FIPS module. The `pw-pbkdf2` module hashes through OpenSSL; to keep password hashing inside the FIPS module, load it and
make `{PBKDF2-SHA512}` the default:

```console
$ printf 'dn: cn=module{0},cn=config\nchangetype: modify\nadd: olcModuleLoad\nolcModuleLoad: pw-pbkdf2.so\n\ndn: olcDatabase={-1}frontend,cn=config\nchangetype: modify\nreplace: olcPasswordHash\nolcPasswordHash: {PBKDF2-SHA512}\n' | \
  docker exec -i openldap ldapmodify -Q -Y EXTERNAL -H ldapi:///
```

Passwords set before the change keep their scheme until they are changed again.

## Non-hardened images vs. Docker Hardened Images

The Bitnami OpenLDAP image configures `slapd` at startup from `LDAP_*` environment variables through shell scripts. This
image has no shell and no environment-driven bootstrap: configuration is a `cn=config` directory seeded with `slapadd`,
or a mounted `slapd.conf`.

| Item              | Bitnami OpenLDAP                                               | Docker Hardened OpenLDAP                                                            |
| ----------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Entry point       | `/opt/bitnami/scripts/openldap/entrypoint.sh`, a Bash script   | `/usr/local/bin/slapd`, with the listeners in the command                           |
| Configuration     | `LDAP_ROOT`, `LDAP_ADMIN_PASSWORD` and other variables         | A seeded `/etc/openldap/slapd.d` or a mounted `slapd.conf`                          |
| Initial data      | LDIF files in `/ldifs`, imported at first start                | `ldapadd` over `ldapi`, or `slapadd` before the first start                         |
| Custom schemas    | LDIF files in `/schemas`, added at first start                 | `include:` lines in the seeded `config.ldif`, or `ldapadd` to `cn=schema,cn=config` |
| Init scripts      | `/docker-entrypoint-initdb.d/*.sh`, run at first start         | None; the image has no shell                                                        |
| LDAPS listener    | `ldaps://:1636/` only with `LDAP_ENABLE_TLS=yes`               | Always on `ldaps://:1636/`; it completes TLS handshakes once a certificate is set   |
| Open files limit  | 1024, set by the entry point script from `LDAP_ULIMIT_NOFILES` | Inherited from the container runtime; set `--ulimit nofile=1024:1024`               |
| User              | UID 1001                                                       | UID 65532                                                                           |
| Configuration dir | `/bitnami/openldap/slapd.d`                                    | `/etc/openldap/slapd.d`                                                             |
| Data dir          | `/bitnami/openldap/data`                                       | `/var/lib/openldap/openldap-data`                                                   |
| Modules           | `/opt/bitnami/openldap/lib/openldap`                           | `/usr/lib/openldap`                                                                 |
| Schemas           | `/opt/bitnami/openldap/etc/schema`                             | `/etc/openldap/schema`                                                              |
| Ports             | 1389 and 1636                                                  | 1389 and 1636                                                                       |

### Migrate a Bitnami deployment

Export the configuration and the directory from the running Bitnami container, here named `bitnami-openldap`. Bitnami
keeps the directory in database 2, because database 1 is `cn=monitor`:

```console
$ docker exec bitnami-openldap slapcat -o ldif_wrap=no -F /bitnami/openldap/slapd.d -n0 > bitnami-config.ldif
$ docker exec bitnami-openldap slapcat -o ldif_wrap=no -F /bitnami/openldap/slapd.d -n2 > bitnami-data.ldif
```

The exported configuration points at Bitnami's paths, never loads `back_mdb` because Bitnami builds MDB into `slapd`,
and gives `cn=config` to Bitnami's UID 1001 over `ldapi`. Rewrite those for this image:

```console
$ awk '
/^olcArgsFile:/ { print "olcArgsFile: /run/openldap/slapd.args"; next }
/^olcPidFile:/ { print "olcPidFile: /run/openldap/slapd.pid"; next }
/^olcModulePath:/ { print "olcModulePath: /usr/lib/openldap"; if (!mdb++) print "olcModuleLoad: back_mdb.so"; next }
/^olcModuleLoad:/ { sub(/\{[0-9]+\}/, "") }
/^olcDbDirectory:/ { print "olcDbDirectory: /var/lib/openldap/openldap-data"; next }
{ gsub(/gidNumber=0\+uidNumber=1001,cn=peercred/, "gidNumber=65532+uidNumber=65532,cn=peercred"); print }
' bitnami-config.ldif > config.ldif
```

If the Bitnami deployment had TLS enabled, also point `olcTLSCertificateFile`, `olcTLSCertificateKeyFile` and
`olcTLSCACertificateFile` in `config.ldif` at the files you mount, as in the LDAPS section. Then create the volumes and
load both files, the data into database 2:

```console
$ docker volume create openldap-config
$ docker volume create openldap-data
$ docker run --rm --entrypoint slapadd \
  -v "$PWD/config.ldif:/config.ldif:ro" \
  -v openldap-config:/etc/openldap/slapd.d \
  dhi.io/openldap:<tag> -n0 -F /etc/openldap/slapd.d -l /config.ldif
$ docker run --rm --entrypoint slapadd \
  -v "$PWD/bitnami-data.ldif:/data.ldif:ro" \
  -v openldap-config:/etc/openldap/slapd.d \
  -v openldap-data:/var/lib/openldap/openldap-data \
  dhi.io/openldap:<tag> -n2 -F /etc/openldap/slapd.d -l /data.ldif
```

Run the server as in the earlier sections. The Bitnami admin DN and the user passwords keep working, and the container
user manages `cn=config` over `ldapi:///`.

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

**OpenLDAP is an exception:** `slapd` hashes passwords with its own code, so `{MD5}` and `{SSHA}` password hashing keeps
working on the FIPS variants. See [Hash passwords on the FIPS tags](#hash-passwords-on-the-fips-tags).

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
