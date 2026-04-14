## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this ClamAV image

This Docker Hardened Image includes:

- ClamAV daemon (`clamd`) for high-performance scanning
- ClamAV scanner (`clamscan`) for on-demand file scanning
- ClamAV daemon scanner (`clamdscan`) for client connections to `clamd`
- FreshClam (`freshclam`) for automatic virus database updates
- Pre-loaded virus signature databases (regular variant) or no databases (base variant)
- Custom entrypoint script (`/usr/local/bin/docker-entrypoint.sh`) that starts both `freshclam` and `clamd`
- CIS benchmark compliance (runtime), FIPS 140 + STIG + CIS compliance (FIPS variant)

## Start a ClamAV instance

Start ClamAV in daemon mode. The default entrypoint starts both `freshclam` (to update virus databases) and `clamd` (the
scanning daemon).

Run the following command and replace `<tag>` with the image variant you want to run (for example, `1.4.3-debian13`):

```console
$ docker run --rm -it dhi.io/clamav:<tag>
```

ClamAV takes approximately 10-15 seconds to initialize. The entrypoint script polls for the `clamd` socket and reports
`socket found, clamd started.` when the daemon is ready.

> **Note:** On first startup, `freshclam` checks for virus database updates. If the bundled databases are outdated, it
> downloads patches before `clamd` becomes available. Subsequent startups with a persistent volume are faster since
> databases are already up to date.

Verify the user the container runs as:

```console
$ docker run --rm --entrypoint whoami dhi.io/clamav:<tag>
clamav
```

The image runs as the `clamav` user by default, not root.

## Common ClamAV use cases

### Update the virus database

The DHI ClamAV comes with two variants:

- The regular variant contains the virus database at the time of image creation.
- The `-base` variant does not contain the virus database and is significantly smaller.

In order to use the `-base` variant or to have an up-to-date virus database, run `freshclam`:

```console
$ docker run --rm --entrypoint freshclam dhi.io/clamav:<tag>
```

By default, the virus database is stored within the running container in `/var/lib/clamav`. Use a volume or a bind mount
to share or persist it across short-lived ClamAV containers.

With a volume, first create the volume and attach the container to it:

```console
$ docker volume create clam_db

$ docker run --rm --entrypoint freshclam \
    --mount source=clam_db,target=/var/lib/clamav \
    dhi.io/clamav:<tag>
```

On subsequent runs with the same volume, `freshclam` skips already-downloaded databases:

```console
$ docker run --rm --entrypoint freshclam \
    --mount source=clam_db,target=/var/lib/clamav \
    dhi.io/clamav:<tag>
ClamAV update process started at ...
daily.cld database is up-to-date (version: 27916, ...)
main.cvd database is up-to-date (version: 63, ...)
bytecode.cvd database is up-to-date (version: 339, ...)
```

With a bind mount, map a local directory to the database path within the container:

```console
$ docker run --rm --entrypoint freshclam \
    --mount type=bind,source=/path/to/databases,target=/var/lib/clamav \
    dhi.io/clamav:<tag>
```

### Scan files with clamscan

To scan files, mount the folder to scan as a bind mount and run `clamscan`. This uses the standalone scanner which loads
the virus database on each invocation:

```console
$ docker run --rm --entrypoint clamscan \
    -v /path/to/scan:/scandir \
    dhi.io/clamav:<tag> /scandir
```

Example scanning a single file:

```console
$ echo "This is a safe test file" > /tmp/testfile.txt

$ docker run --rm --entrypoint clamscan \
    -v /tmp/testfile.txt:/scandir/testfile.txt \
    dhi.io/clamav:<tag> /scandir/testfile.txt
/scandir/testfile.txt: OK
----------- SCAN SUMMARY -----------
Known viruses: 3627519
Engine version: 1.4.3
Infected files: 0
```

To verify detection, test with the EICAR test signature:

```console
$ echo -n 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/eicar.txt

$ docker run --rm --entrypoint clamscan \
    -v /tmp/eicar.txt:/scandir/eicar.txt \
    dhi.io/clamav:<tag> /scandir/eicar.txt
/scandir/eicar.txt: Eicar-Test-Signature FOUND
----------- SCAN SUMMARY -----------
Known viruses: 3627519
Engine version: 1.4.3
Infected files: 1
```

### Scan files with clamdscan (daemon mode)

For high-throughput scanning, run ClamAV in daemon mode and use `clamdscan` to submit files. The daemon keeps the virus
database loaded in memory, making scans significantly faster (~0.04s vs ~10s per file):

```console
$ docker run -d --name clamav-daemon \
    --mount source=clam_db,target=/var/lib/clamav \
    dhi.io/clamav:<tag>
```

Wait for the daemon to become ready (~15 seconds), then scan:

```console
$ docker exec clamav-daemon clamdscan --version
ClamAV 1.4.3/27916/...

$ docker exec clamav-daemon sh -c "echo 'safe test file' > /tmp/test.txt && clamdscan /tmp/test.txt"
/tmp/test.txt: OK
----------- SCAN SUMMARY -----------
Infected files: 0
Time: 0.041 sec (0 m 0 s)
```

### Expose ClamAV as a network service

ClamDScan can also connect over a TCP port or Unix socket for use by external applications:

```console
$ docker run -d --name clamav-daemon \
    -p 3310:3310 \
    --mount source=clam_db,target=/var/lib/clamav \
    dhi.io/clamav:<tag>
```

Or via a Unix socket using a bind mount:

```console
$ docker run -d --name clamav-daemon \
    --mount type=bind,source=/path/to/sockets,target=/tmp \
    --mount source=clam_db,target=/var/lib/clamav \
    dhi.io/clamav:<tag>
```

### Deploy ClamAV in Kubernetes

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

Create the namespace and Deployment:

```console
$ kubectl create namespace scanning
```

> **Note:** The ClamAV DHI entrypoint runs `chown` on `/var/lib/clamav` at startup to set correct ownership. You must
> set `runAsUser: 0` in the security context so that the entrypoint can set permissions before dropping to the `clamav`
> user internally.

```yaml
# clamav-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clamav
  namespace: scanning
spec:
  replicas: 1
  selector:
    matchLabels:
      app: clamav
  template:
    metadata:
      labels:
        app: clamav
    spec:
      containers:
      - name: clamav
        image: dhi.io/clamav:<tag>
        ports:
        - containerPort: 3310
          name: clamd
        securityContext:
          runAsUser: 0
        volumeMounts:
        - name: clam-db
          mountPath: /var/lib/clamav
      volumes:
      - name: clam-db
        emptyDir: {}
      imagePullSecrets:
      - name: <secret name>
```

```console
$ kubectl apply -f clamav-deployment.yaml

$ kubectl get pods -n scanning
```

You can find more documentation about using ClamAV at https://docs.clamav.net/manual/Installing/Docker.html.

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature             | DOI (`clamav/clamav`) | DHI (`dhi.io/clamav`)                            |
| ------------------- | --------------------- | ------------------------------------------------ |
| User                | root (unset)          | `clamav`                                         |
| Shell               | Yes (Alpine `sh`)     | Yes (`dash`)                                     |
| Package manager     | Yes (`apk`)           | No                                               |
| Entrypoint          | `/init`               | `/usr/local/bin/docker-entrypoint.sh`            |
| Uncompressed size   | 342 MB                | 429 MB (regular) / 203 MB (base) / 504 MB (FIPS) |
| Zero CVE commitment | No                    | Yes                                              |
| FIPS variant        | No                    | Yes (FIPS + STIG + CIS)                          |
| Base variant        | Yes                   | Yes (no virus database)                          |
| Base OS             | Alpine Linux 3.23.3   | Docker Hardened Images (Debian 13)               |
| Compliance labels   | None                  | CIS (runtime), FIPS+STIG+CIS (fips)              |
| ENV: TZ             | `Etc/UTC`             | `Etc/UTC`                                        |
| Architectures       | amd64 only            | amd64, arm64                                     |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag. For ClamAV DHI images, the following variants are available:

**Regular variants** are preloaded with the virus signature databases available at the time of the image build. These
are ready to scan immediately on startup and are the recommended choice for most deployments. Regular variants
typically:

- Run as the `clamav` user
- Include a `dash` shell but no package manager
- Contain the ClamAV binaries, configuration, and pre-loaded virus databases
- Include CIS benchmark compliance (`com.docker.dhi.compliance: cis`)

**Base variants** include `-base` in the tag and do not contain the virus signature databases. These are significantly
smaller (203 MB vs 429 MB) and are intended for environments where you manage your own database updates or share
databases across containers via volumes.

**FIPS variants** include `fips` in the tag. These variants use cryptographic modules that have been validated under
FIPS 140, a U.S. government standard for secure cryptographic operations. FIPS variants also include STIG and CIS
compliance (`com.docker.dhi.compliance: fips,stig,cis`). For example, usage of MD5 fails in FIPS variants. Use FIPS
variants in regulated environments such as FedRAMP, government, and financial services.

**FIPS base variants** include both `-base` and `-fips` in the tag. These combine FIPS compliance with the smaller base
image that does not include virus databases.

> **Note:** No `dev` variant exists for ClamAV DHI. For debugging, use
> [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to running containers, or use the
> built-in `dash` shell via `docker exec <container> sh -c "<command>"`.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                                                    |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

## Troubleshoot migration

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
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
