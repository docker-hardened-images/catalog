## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this cert-manager-startupapicheck image

This Docker Hardened cert-manager-startupapicheck image includes:

- The startupapicheck binary: a small CLI that validates cert-manager API server endpoints and critical components are
  available and healthy.

## Start a cert-manager-startupapicheck image

> **Note:** The cert-manager-acmesolver image is primarily designed to run inside a Kubernetes cluster as part of a full
> cert-manager deployment. The standalone Docker command below simply displays configuration options.

The cert-manager-startupapicheck utility is typically executed as a one-shot process (Kubernetes Job or ad-hoc
container) to verify that cert-manager has started successfully. It does not expose long-lived HTTP ports — it runs
checks against the Kubernetes API and cert-manager API and returns a non-zero exit code on failure.

### Basic usage

```bash
# Run the check against the in-cluster API (requires kubeconfig or in-cluster credentials)
docker run --rm --name cert-manager-startupapicheck \
  dhi.io/cert-manager-startupapicheck:<tag> help
```

### Environment variables

The upstream utility accepts configuration via command-line flags and commonly uses the Kubernetes client configuration.
When running via Docker, the following environment variables and mounts are commonly used to provide cluster access.

| Variable   | Description                                                                      | Default | Required                                                         |
| ---------- | -------------------------------------------------------------------------------- | ------- | ---------------------------------------------------------------- |
| KUBECONFIG | Path inside container to a kubeconfig file used to connect to the target cluster | none    | No (either provide KUBECONFIG or rely on in-cluster credentials) |
| VERBOSE    | Enable verbose logging output (if supported by binary)                           | false   | No                                                               |

Example:

```bash
$ docker run --rm -v ~/.kube/config:/kube/config:ro -e KUBECONFIG=/kube/config \
  dhi.io/cert-manager-startupapicheck:<tag>
```

## Non-hardened images vs. Docker Hardened Images

This Docker Hardened image provides the same runtime behavior as the upstream image (startupapicheck) but is built and
published according to the Docker Hardened Images security practices: minimal attack surface, signed provenance, SBOM
and VEX metadata. There are no functional differences in how you run the tool.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

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

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

**Note:** cert-manager consists of multiple components (controller, acmesolver, cainjector, webhook) that work together.
Each component may be available as a separate Docker Hardened Image for deployment flexibility.

### FIPS variants considerations

For allowing FIPS in this image, there are some DNS standards that still use non-FIPS compliant algorithms and cannot be
changed:

1. [RFC2136](https://cert-manager.io/docs/configuration/acme/dns01/rfc2136/) DNS-01 solver
   ([tsigHMACProvider.Generate](https://github.com/cert-manager/cert-manager/blob/master/pkg/issuer/acme/dns/rfc2136/tsig.go#L49))

If you want to use the RFC2136 DNS-01 solver, there are two signatures that are forbidden by FIPS and the application
will Panic (sha1 and md5), some of the DNS servers may require these legacy algorithms for TSIG authentication, removing
those would break compatibility with existing DNS infrastructure.

A way to mitigate this is to specifying in the `spec.acme.solvers[dnsXX].rfc2136.tsigAlgorithm` spec of your `Issuer` or
`ClusterIssuer` with some FIPS-approved algorithm.

Example:

```yaml
  apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: example-rfc2136
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: example-account-key
    solvers:
    - dns01:
        rfc2136:
          nameserver: 203.0.113.53:53
          tsigKeyName: example-com-key
          tsigAlgorithm: HMACSHA512 # <- choose your algorithm here
          tsigSecretSecretRef:
            name: tsig-secret
            key: tsig-secret-key
```

2. Legacy TLS cipher suites (RC4, ChaCha20, SHA1...):

Cert-manager supports non FIPS-compliant
[ciphers](https://github.com/cert-manager/cert-manager/blob/d7090f55e7aae3ebee6a0917a2b59eef37e36c75/third_party/forked/acme/autocert/autocert.go#L363)
from the go's autocert library, and is needed for the ACME client to be compatible with older DNS servers.

cert-manager's fork of "Go's autocert" is part of a function (supportsECDSA) that decides whether to serve an ECDSA
certificate based on what the client's TLS handshake says it supports

Note: These are only supported, not preferred - modern clients will negotiate stronger ciphers

3. PKCS#12 legacy profiles (DES and RC2): Cert Manager supports
   [LegacyDESPKCS12Profile and LegacyRC2PKCS12Profile](https://github.com/cert-manager/cert-manager/blob/d7090f55e7aae3ebee6a0917a2b59eef37e36c75/pkg/controller/certificates/issuing/internal/keystore.go#L68-L73)
   using DES and RC2, those are required for backward compatibility with systems that only support legacy PKCS#12
   formats. Even cert manager states that this is an experimental feature, Modern2023 profile is available as
   FIPS-compliant alternative

Remediation: Avoid keystores entirely or use the
[Modern 2023](https://github.com/cert-manager/cert-manager/blob/v1.19.1/pkg/apis/certmanager/v1/types_certificate.go#L536)
Certificate profile which supports secure algorithms.

4. CHACHA20_POLY1305 cipher
   [scheme support](https://github.com/cert-manager/cert-manager/blob/d7090f55e7aae3ebee6a0917a2b59eef37e36c75/third_party/forked/acme/autocert/autocert.go#L337):
   `autocert.go` Defines the `tlsECDSAWithSHA1` constant for client compatibility, it's logic checks the client's
   offered cipher suites, if the client supports the `TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305` cipher the application
   will panic.

Remediation: Ensure your FIPS-compliant stack does not negotiate the `TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305` as a valid
cipher.

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
