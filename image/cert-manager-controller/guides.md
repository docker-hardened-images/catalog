## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this cert-manager-controller image

This Docker Hardened cert-manager-controller image includes the controller component of cert-manager in a single,
security-hardened package:

- `cert-manager` controller binary (`/usr/local/bin/cert-manager`) that manages certificate lifecycle operations,
  watches for Certificate resources, and coordinates with ACME providers
- TLS certificate management capabilities for Kubernetes clusters
- ACME protocol support for automatic certificate provisioning from providers like Let's Encrypt
- Certificate renewal automation and lifecycle management
- Healthz endpoint for liveness and readiness probes
- CIS benchmark compliance (runtime), FIPS 140 + STIG + CIS compliance (FIPS variant)

## Start a cert-manager-controller image

> **Note:** The cert-manager-controller image is primarily designed to run inside a Kubernetes cluster as part of a full
> cert-manager deployment. The standalone Docker command below displays the available configuration options.

Run the following command and replace `<tag>` with the image variant you want to run (for example, `1.19.3-debian13`).

```console
$ docker run --rm dhi.io/cert-manager-controller:<tag> --help
```

## Controller-specific flags

The cert-manager-controller supports several configuration flags to customize its behavior for different deployment
scenarios.

### Select which controllers to run

The `--controllers` flag specifies which internal controllers to run. By default, cert-manager runs all controllers
including certificates, orders, challenges, and issuers.

You can limit which controllers run by providing a comma-separated list:

```console
$ docker run --rm dhi.io/cert-manager-controller:<tag> \
  --controllers=certificates-issuing,issuers
```

You can also disable specific controllers while keeping others enabled. Note the quotes around the argument to prevent
shell glob expansion:

```console
$ docker run --rm dhi.io/cert-manager-controller:<tag> \
  '--controllers=*,-foo'
```

This configuration is particularly useful in high-availability setups where different cert-manager-controller instances
can split responsibilities for improved performance and reliability.

### Configure certificate ownership of secrets

The `--enable-certificate-owner-ref` flag controls whether Certificates set an OwnerReference on their Secret resources.

When disabled (default behavior), Secrets persist after Certificate deletion, allowing them to be reused or requiring
manual cleanup.

When enabled, Kubernetes automatically garbage-collects the corresponding Secret when a Certificate is deleted.

```console
$ docker run --rm dhi.io/cert-manager-controller:<tag> \
  --enable-certificate-owner-ref=true
```

**Warning:** Enabling this flag can be dangerous in scenarios where Secrets are shared between multiple resources.
Deleting one Certificate could unintentionally remove a Secret still in use by another resource.

### Set cluster resource namespace

The `--cluster-resource-namespace` flag defines the namespace where cluster-scoped resources like ClusterIssuers store
their Secrets.

The default namespace is `kube-system`. This configuration is necessary because ClusterIssuers are cluster-wide
resources not bound to a single namespace, but their credential Secrets must still reside in a specific namespace.

```console
$ docker run --rm dhi.io/cert-manager-controller:<tag> \
  --cluster-resource-namespace=cert-manager
```

## Common cert-manager-controller use cases

### Generate and manage SSL certificates for your cluster for free

cert-manager automates the management and issuance of TLS certificates from various certificate authorities, including
free providers like Let's Encrypt. It ensures certificates are valid and attempts to renew them before expiry.

The following example shows a Certificate CRD for Let's Encrypt:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-com-tls
  namespace: default
spec:
  secretName: example-com-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - example.com
  - www.example.com
```

### Deploy cert-manager-controller in Kubernetes

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

The controller is typically deployed as part of a complete cert-manager installation in Kubernetes.

> **Note:** The Docker Hardened Image uses the string `nonroot` as the user, which causes a `CreateContainerConfigError`
> with Kubernetes' `runAsNonRoot` validation. You must explicitly set `runAsUser: 65532` in the security context to
> resolve this.

The following example shows a Deployment configuration for cert-manager-controller:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  template:
    spec:
      containers:
      - name: cert-manager-controller
        image: dhi.io/cert-manager-controller:<tag>
        args:
        - --v=2
        - --cluster-resource-namespace=$(POD_NAMESPACE)
        - --leader-election-namespace=$(POD_NAMESPACE)
        securityContext:
          runAsUser: 65532
      imagePullSecrets:
      - name: <secret name>
```

When deploying with Helm, include the `securityContext.runAsUser` override:

```console
$ helm install cert-manager oci://registry-1.docker.io/dhi/cert-manager-chart \
  -n cert-manager --create-namespace \
  --set crds.enabled=true \
  --set image.registry=dhi.io \
  --set image.tag=1.19.3-debian13 \
  --set securityContext.runAsUser=65532 \
  --set "global.imagePullSecrets[0].name"=helm-pull-secret
```

> **Note:** Ensure the `--set crds.enabled=true` flag is included so that cert-manager CRDs are installed. Without this,
> Certificate and Issuer resources won't be available in the cluster. For older Helm chart versions, use
> `--set installCRDs=true` instead.

### Integrate with multiple certificate authorities

cert-manager-controller supports various certificate issuers including ACME (Let's Encrypt), self-signed, CA, Vault, and
Venafi.

The following example shows a ClusterIssuer configuration for Let's Encrypt:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature             | DOI (`quay.io/jetstack/cert-manager-controller`) | DHI (`dhi.io/cert-manager-controller`)  |
| ------------------- | ------------------------------------------------ | --------------------------------------- |
| User                | `1000` (numeric UID)                             | `nonroot` (runtime/FIPS) / `root` (dev) |
| Shell               | No                                               | No (runtime/FIPS) / Yes (dev)           |
| Package manager     | No                                               | No (runtime/FIPS) / Yes (dev)           |
| Binary path         | `/app/cmd/controller/controller`                 | `/usr/local/bin/cert-manager`           |
| Entrypoint          | ENTRYPOINT `controller`                          | ENTRYPOINT `cert-manager`               |
| Zero CVE commitment | No                                               | Yes                                     |
| FIPS variant        | No                                               | Yes (FIPS + STIG + CIS)                 |
| Base OS             | Minimal (no labels)                              | Docker Hardened Images (Debian 13)      |
| Uncompressed size   | 100 MB                                           | 110 MB (runtime), 182 MB (FIPS)         |
| Layers              | 15                                               | 7 (runtime)                             |
| Compliance labels   | None                                             | CIS (runtime), FIPS+STIG+CIS (fips)     |
| ENV: SSL_CERT_FILE  | `/etc/ssl/certs/ca-certificates.crt`             | `/etc/ssl/certs/ca-certificates.crt`    |
| Architectures       | amd64, arm64                                     | amd64, arm64                            |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

**Runtime variants** are designed to run the cert-manager controller in production. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the `cert-manager` binary and TLS certificates
- Include CIS benchmark compliance (`com.docker.dhi.compliance: cis`)

**Build-time variants** typically include `dev` in the tag name and are intended for debugging and development. These
images typically:

- Run as the root user
- Include a shell and package manager
- Are useful for troubleshooting cert-manager issues

**FIPS variants** include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. FIPS variants also include STIG and CIS compliance
(`com.docker.dhi.compliance: fips,stig,cis`). For example, usage of MD5 fails in FIPS variants. Use FIPS variants in
regulated environments such as FedRAMP, government, and financial services.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

**Note:** cert-manager consists of multiple components (controller, acmesolver, cainjector, webhook) that work together.
Each component may be available as a separate Docker Hardened Image for deployment flexibility.

### FIPS variants considerations

The FIPS variant has known compatibility constraints with legacy cryptographic algorithms:

| Area                  | Issue                                                                                    | Remediation                                                                     |
| --------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| RFC2136 DNS-01 solver | SHA1 and MD5 TSIG signatures are forbidden in FIPS mode                                  | Set `tsigAlgorithm: HMACSHA512` in your Issuer/ClusterIssuer                    |
| TLS cipher suites     | Legacy ciphers (RC4, ChaCha20, SHA1) are supported in code for ACME client compatibility | Modern clients negotiate stronger ciphers automatically; no action needed       |
| PKCS#12 profiles      | LegacyDES and LegacyRC2 profiles use non-FIPS algorithms                                 | Use the `Modern2023` certificate profile                                        |
| CHACHA20_POLY1305     | ChaCha20Poly1305 is not allowed in FIPS 140 mode and returns an error if used            | Ensure your TLS stack does not require `TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305` |

For RFC2136, specify a FIPS-approved algorithm in your solver configuration:

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
          tsigAlgorithm: HMACSHA512
          tsigSecretSecretRef:
            name: tsig-secret
            key: tsig-secret-key
```

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or Kubernetes manifests. At
minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This and a few other
common changes are listed in the following table of migration notes:

| Item               | Migration note                                                                                                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile or Kubernetes manifests with a Docker Hardened Image.                                                                                  |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                          |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                         |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                             |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                 |
| Ports              | Non-dev hardened images run as a nonroot user by default. cert-manager-controller typically uses port 9402 for metrics, which works without issues.                                |
| Entry point        | Docker Hardened Images may have different entry points than standard cert-manager images. Inspect entry points for Docker Hardened Images and update your deployment if necessary. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.        |
| Kubernetes RBAC    | Ensure RBAC permissions are correctly configured as cert-manager-controller requires specific permissions to manage certificates and secrets.                                      |

The following steps outline the general migration process.

1. **Find hardened images for your app.** The cert-manager-controller hardened image may have several variants. Inspect
   the image tags and find the image variant that meets your needs. Remember that cert-manager requires multiple
   components to function properly.
1. **Update the image references in your Kubernetes manifests.** Update the image references in your cert-manager
   deployment manifests to use the hardened images. If using Helm, update your values file accordingly.
1. **For custom deployments, update the runtime image in your Dockerfile.** If you're building custom images based on
   cert-manager, ensure that your final image uses the hardened cert-manager-controller as the base.
1. **Verify component compatibility** Ensure all cert-manager components (controller, webhook, cainjector, acmesolver)
   are using compatible versions. The controller works in conjunction with these other components.
1. **Test certificate issuance** After migration, test that certificate issuance and renewal workflows continue to
   function correctly with the hardened images.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

cert-manager-controller requires write access to create and manage certificate secrets in the cluster. Ensure your RBAC
configuration grants appropriate permissions.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than standard cert-manager images. Use `docker inspect` to
inspect entry points for Docker Hardened Images and update your Kubernetes deployment if necessary.
