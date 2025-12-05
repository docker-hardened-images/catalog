## How to use this image

### What's included in this cert-manager-cainjector image

This Docker Hardened cert-manager-cainjector image includes the cainjector component of cert-manager in a single,
security-hardened package:

- `cert-manager-cainjector`: The CA injector binary that automatically injects CA certificate data into Kubernetes
  webhook configurations and API services
- CA bundle injection capabilities for Mutating Webhooks, Validating Webhooks, Conversion Webhooks, and API Services
- Support for injecting CA data from Certificate resources, Secret resources, or the Kubernetes API server CA
- Automatic population of `caBundle` fields to help the Kubernetes API server verify serving certificates

## Start a cert-manager-cainjector image

> **Note:** The cert-manager-acmesolver image is primarily designed to run inside a Kubernetes cluster as part of a full
> cert-manager deployment. The standalone Docker command below simply displays configuration options.

Run the following command and replace `<your-namespace>` with your organization's namespace and `<tag>` with the image
variant you want to run.

**Note:** cert-manager-cainjector is designed to run within a Kubernetes cluster to inject CA certificate data into
webhook configurations. The following standalone Docker command displays the available configuration options.

```bash
docker run --rm -it <your-namespace>/dhi-cert-manager-cainjector:<tag> --help
```

### Configure injection sources

The cainjector can inject CA data from three sources:

- Certificate resources (using `cert-manager.io/inject-ca-from` annotation)
- Secret resources (using `cert-manager.io/inject-ca-from-secret` annotation)
- Kubernetes API server CA (using `cert-manager.io/inject-apiserver-ca` annotation)

These injection sources can be controlled through annotations on target resources.

### Configure namespace filtering

The `--namespace` flag restricts the cainjector to only watch resources to a SINGLE namespace. By default, it watches
all namespaces.

```bash
docker run --rm -it <your-namespace>/dhi-cert-manager-cainjector:<tag> \
  --namespace=cert-manager
```

## Common cert-manager-cainjector use cases

### Inject CA certificates into webhook configurations

The cainjector automatically populates CA bundles for Kubernetes admission webhooks to enable secure communication
between the API server and webhook endpoints.

The following example shows a ValidatingAdmissionWebhook with CA injection annotation:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: my-webhook
  annotations:
    cert-manager.io/inject-ca-from: webhook-ns/webhook-certificate
webhooks:
- name: webhook.example.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-ns
      path: /validate
    # caBundle will be automatically populated by cainjector
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

### Inject CA from Secret resources

You can inject CA data directly from Kubernetes Secrets using the `inject-ca-from-secret` annotation. The secret type
must be [kubernetes.io/tls](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionWebhook
metadata:
  name: my-mutating-webhook
  annotations:
    cert-manager.io/inject-ca-from-secret: webhook-ns/ca-secret
webhooks:
- name: mutate.example.com
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-ns
      path: /mutate
    # caBundle will be populated from the ca-secret Secret
```

### Deploy cert-manager-cainjector in Kubernetes

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

The cainjector is typically deployed as part of a complete cert-manager installation in Kubernetes.

The following example shows a Deployment configuration for cert-manager-cainjector:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-manager-cainjector
  namespace: cert-manager
spec:
  template:
    spec:
      containers:
      - name: cert-manager-cainjector
        image: <your-namespace>/dhi-cert-manager-cainjector:<tag>
        args:
        - --v=2
        - --cluster-resource-namespace=$(POD_NAMESPACE)
        - --leader-election-namespace=$(POD_NAMESPACE)
      imagePullSecrets:
      - name: <secret name>
```

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
| Ports              | Non-dev hardened images run as a nonroot user by default. cert-manager-cainjector typically uses port 9402 for metrics, which works without issues.                                |
| Entry point        | Docker Hardened Images may have different entry points than standard cert-manager images. Inspect entry points for Docker Hardened Images and update your deployment if necessary. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.        |
| Kubernetes RBAC    | Ensure RBAC permissions are correctly configured as cert-manager-cainjector requires specific permissions to watch and modify webhook configurations and API services.             |

The following steps outline the general migration process.

1. **Find hardened images for your app.** The cert-manager-cainjector hardened image may have several variants. Inspect
   the image tags and find the image variant that meets your needs. Remember that cert-manager requires multiple
   components to function properly.
1. **Update the image references in your Kubernetes manifests.** Update the image references in your cert-manager
   deployment manifests to use the hardened images. If using Helm, update your values file accordingly.
1. **For custom deployments, update the runtime image in your Dockerfile.** If you're building custom images based on
   cert-manager, ensure that your final image uses the hardened cert-manager-cainjector as the base.
1. **Verify component compatibility** Ensure all cert-manager components (controller, webhook, cainjector, acmesolver)
   are using compatible versions. The cainjector works in conjunction with these other components.
1. **Test CA injection** After migration, test that webhook configurations are properly receiving CA bundle injections
   and that API server communication with webhooks continues to function correctly.

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

cert-manager-cainjector requires read access to Certificate and Secret resources, and write access to webhook
configurations and API services to inject CA bundles. Ensure your RBAC configuration grants appropriate permissions.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than standard cert-manager images. Use `docker inspect` to
inspect entry points for Docker Hardened Images and update your Kubernetes deployment if necessary.

### cert-manager-cainjector specific troubleshooting

- **Missing CA bundles**: If webhook configurations are missing CA bundles, check that the cainjector is running and has
  proper RBAC permissions to read Certificate/Secret resources and modify webhook configurations.
- **Annotation issues**: Verify that webhook resources have the correct injection annotations
  (`cert-manager.io/inject-ca-from`, `cert-manager.io/inject-ca-from-secret`, or `cert-manager.io/inject-apiserver-ca`).
- **Source resource missing**: If using `inject-ca-from`, ensure the referenced Certificate resource exists and has a
  valid CA certificate. If using `inject-ca-from-secret`, verify the Secret exists and contains the expected CA data.
- **Webhook communication failures**: If the API server cannot communicate with webhooks, check that CA bundles were
  properly injected and that the webhook's serving certificate was issued by the expected CA.
