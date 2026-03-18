## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this cert-manager-webhook image

This Docker Hardened cert-manager-webhook image includes the webhook component of cert-manager in a single,
security-hardened package:

- `cert-manager-webhook`: The webhook binary that uses
  [dynamic admission control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
  to validate, mutate, or convert cert-manager resources
- Dynamic admission control support for `ValidatingWebhookConfiguration` and `MutatingWebhookConfiguration`
- Conversion webhook support for CRD multi-version API serving
- TLS certificate support for securing communication between the Kubernetes API server and the webhook server

## Start a cert-manager-webhook image

> **Note:** cert-manager-webhook is primarily designed to run inside a Kubernetes cluster as part of a full cert-manager
> deployment. The following standalone Docker command displays the available configuration options.

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run --rm dhi.io/cert-manager-webhook:<tag> --help
```

### Configure TLS

The webhook component is deployed as a pod that runs alongside the cert-manager controller and CA injector components.
In order for the API server to communicate with the webhook component, the webhook requires a TLS certificate that the
apiserver is configured to trust.

The webhook creates `secret/cert-manager-webhook-ca` in the namespace where the webhook is deployed. This secret
contains a self-signed root CA certificate which is used to sign certificates for the webhook pod in order to fulfill
this requirement.

Then the webhook can be configured with either:

- Paths to a TLS certificate and key signed by the webhook CA, or
- A reference to the CA Secret for dynamic generation of the certificate and key on webhook startup

### Command-line flags

The webhook binary accepts configuration via command-line flags. When running via Docker, commonly used flags include:

| Flag                     | Description                                                                      | Default | Required                                                             |
| ------------------------ | -------------------------------------------------------------------------------- | ------- | -------------------------------------------------------------------- |
| `--kubeconfig`           | Path inside container to a kubeconfig file used to connect to the target cluster | none    | No (either provide `--kubeconfig` or rely on in-cluster credentials) |
| `--secure-port`          | Port number the webhook server listens on for HTTPS traffic                      | 6443    | No                                                                   |
| `--tls-cert-file`        | Path to the TLS certificate file for the webhook server                          | none    | Yes (or use CA Secret reference for dynamic generation)              |
| `--tls-private-key-file` | Path to the TLS private key file for the webhook server                          | none    | Yes (or use CA Secret reference for dynamic generation)              |
| `-v`, `--v`              | Log level verbosity (number)                                                     | 0       | No                                                                   |

Example:

```bash
# Mount kubeconfig and use --kubeconfig flag
docker run --rm -v ~/.kube/config:/kube/config:ro \
  dhi.io/cert-manager-webhook:<tag> --kubeconfig /kube/config

# Enable verbose logging
docker run --rm dhi.io/cert-manager-webhook:<tag> -v 2
```

## Common cert-manager-webhook use cases

### Validate cert-manager resources

The webhook intercepts CREATE and UPDATE requests for cert-manager resources and validates them against cert-manager's
admission rules before they are persisted to etcd. This prevents misconfigured Certificate, Issuer, and ClusterIssuer
resources from being accepted by the cluster.

The `ValidatingWebhookConfiguration` is created and managed automatically by cert-manager when you install it. You do
not apply it manually. The following shows the actual configuration deployed by cert-manager v1.19.4, retrieved with
`kubectl get validatingwebhookconfiguration cert-manager-webhook -o yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: cert-manager-webhook
  annotations:
    cert-manager.io/inject-ca-from-secret: cert-manager/cert-manager-webhook-ca
webhooks:
- name: webhook.cert-manager.io
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Fail
  matchPolicy: Equivalent
  timeoutSeconds: 30
  clientConfig:
    service:
      name: cert-manager-webhook
      namespace: cert-manager
      path: /validate
      port: 443
    # caBundle populated automatically by cainjector
  namespaceSelector:
    matchExpressions:
    - key: cert-manager.io/disable-validation
      operator: NotIn
      values:
      - "true"
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["cert-manager.io", "acme.cert-manager.io"]
    apiVersions: ["v1"]
    resources: ["*/*"]
```

To verify the webhook is validating resources, apply an invalid Certificate with missing required fields:

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: invalid-cert
  namespace: cert-manager
spec:
  secretName: ""
  issuerRef:
    name: ""
EOF
```

Expected output:

```
Error from server (Forbidden): error when creating "STDIN": admission webhook "webhook.cert-manager.io"
denied the request: [spec.secretName: Required value: must be specified,
spec.issuerRef.name: Required value: must be specified,
spec: Invalid value: "": at least one of commonName (from the commonName field or from a literalSubject),
dnsNames, uriSANs, ipAddresses, emailSANs or otherNames must be set]
```

### Mutate cert-manager resources

The webhook mutates incoming `CertificateRequest` resources on CREATE by injecting the identity of the requesting user —
specifically the `username`, `groups`, and `extra` fields. This allows cert-manager to enforce RBAC-based approval
policies on certificate requests.

The `MutatingWebhookConfiguration` is created and managed automatically by cert-manager when you install it. You do not
apply it manually. The following shows the actual configuration deployed by cert-manager v1.19.4, retrieved with
`kubectl get mutatingwebhookconfiguration cert-manager-webhook -o yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: cert-manager-webhook
  annotations:
    cert-manager.io/inject-ca-from-secret: cert-manager/cert-manager-webhook-ca
webhooks:
- name: webhook.cert-manager.io
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Fail
  matchPolicy: Equivalent
  timeoutSeconds: 30
  clientConfig:
    service:
      name: cert-manager-webhook
      namespace: cert-manager
      path: /mutate
      port: 443
    # caBundle populated automatically by cainjector
  rules:
  - operations: ["CREATE"]
    apiGroups: ["cert-manager.io"]
    apiVersions: ["v1"]
    resources: ["certificaterequests"]
```

To verify mutation is working, create a Certificate and inspect the resulting CertificateRequest to confirm the webhook
injected the `username`, `groups`, and `extra` fields:

```bash
kubectl get certificaterequest -n cert-manager -o jsonpath='{.items[0].spec.username}{"\n"}{.items[0].spec.groups}{"\n"}'
```

Expected output:

```
system:serviceaccount:cert-manager:cert-manager
["system:serviceaccounts","system:serviceaccounts:cert-manager","system:authenticated"]
```

### End-to-end webhook deployment walkthrough

The following steps demonstrate a complete cert-manager-webhook deployment, validated against cert-manager v1.19.4 and
`dhi.io/cert-manager-webhook:1-debian13`.

**Prerequisites**: A running Kubernetes cluster with `kubectl` and `helm` access. All cert-manager components must use
Docker Hardened Images. The recommended way to install all components together is via the DHI Helm chart, which deploys
`dhi.io/cert-manager-controller`, `dhi.io/cert-manager-cainjector`, `dhi.io/cert-manager-webhook`, and
`dhi.io/cert-manager-acmesolver` automatically:

```bash
# Create the namespace and imagePullSecret first
kubectl create namespace cert-manager

kubectl create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<your-docker-username> \
  --docker-password=<your-docker-password> \
  -n cert-manager

# Install all cert-manager components using the DHI Helm chart
helm install my-cert-manager oci://dhi.io/cert-manager-chart --version 1 \
  --namespace cert-manager \
  --set "imagePullSecrets[0].name=helm-pull-secret"

# Wait for all pods to be ready
kubectl wait --for=condition=Ready pod --all -n cert-manager --timeout=120s
```

**Step 1: Verify all pods are running DHI images**

```bash
kubectl get pods -n cert-manager
# NAME                                         READY   STATUS    RESTARTS   AGE
# my-cert-manager-xxx                          1/1     Running   0          73s
# my-cert-manager-cainjector-xxx               1/1     Running   0          73s
# my-cert-manager-webhook-xxx                  1/1     Running   0          73s

# Confirm DHI images are in use
kubectl get pods -n cert-manager -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.containers[0].image}{"\n"}{end}'
```

**Step 2: Check webhook logs**

```bash
kubectl logs -n cert-manager deployment/my-cert-manager-webhook | grep -E "Starting|listening|ready"
# I0312 07:10:35  "starting cert-manager webhook" version="1.19.4"
# I0312 07:10:35  "listening for requests" address=":6443"
```

**Step 3: Verify webhook TLS**

Within seconds of startup, the webhook generates its serving certificate from the CA Secret. Verify the CA Secret was
created and inspect the certificate:

```bash
kubectl get secret my-cert-manager-webhook-ca -n cert-manager
# NAME                          TYPE     DATA   AGE
# my-cert-manager-webhook-ca    Opaque   3      45s

kubectl get secret my-cert-manager-webhook-ca -n cert-manager \
  -o jsonpath='{.data.ca\.crt}' | base64 -d \
  | openssl x509 -text -noout | grep -E "Subject:|Not After"
```

**Step 4: Create a self-signed Issuer**

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
  namespace: cert-manager
spec:
  selfSigned: {}
EOF
```

**Step 5: Test admission control**

```bash
# Apply a valid Certificate — should succeed
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: cert-manager
spec:
  secretName: test-cert-tls
  issuerRef:
    name: selfsigned-issuer
    kind: Issuer
  commonName: test.example.com
  dnsNames:
  - test.example.com
EOF

# Apply an invalid Certificate — should be rejected by the webhook
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: invalid-cert
  namespace: cert-manager
spec:
  secretName: ""
  issuerRef:
    name: ""
EOF
# Expected: Error from server: ... spec.secretName: Required value
```

**Step 6: Clean up**

```bash
kubectl delete certificate test-cert -n cert-manager
kubectl delete issuer selfsigned-issuer -n cert-manager
helm uninstall my-cert-manager -n cert-manager
kubectl delete secret helm-pull-secret -n cert-manager
kubectl delete namespace cert-manager
```

## Official images vs Docker Hardened Images

| Feature             | DOI (`quay.io/jetstack/cert-manager-webhook`) | DHI (`dhi.io/cert-manager-webhook`)                 |
| ------------------- | --------------------------------------------- | --------------------------------------------------- |
| **User**            | `1000` (numeric UID)                          | `nonroot` / UID 65532 (runtime/FIPS) / `root` (dev) |
| **Shell**           | Typically included                            | No (runtime/FIPS) / Yes (dev)                       |
| **Package manager** | Varies                                        | No (runtime/FIPS) / APT (dev)                       |
| **Binary path**     | `/app/cmd/webhook/webhook`                    | `/app/cmd/webhook/webhook`                          |
| **Entrypoint**      | `["/app/cmd/webhook/webhook"]`                | `["/app/cmd/webhook/webhook"]`                      |

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

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

**Note:** cert-manager consists of multiple components (controller, acmesolver, cainjector, webhook) that work together.
Each component may be available as a separate Docker Hardened Image for deployment flexibility.

### FIPS variants considerations

FIPS variants (`1-fips`, `1-debian13-fips`, `1.19-fips`, `1.19.4-fips`, `1.19.4-debian13-fips`) are available on Docker
Hub and carry CIS, FIPS, and STIG compliance badges with 0 vulnerabilities. Pulling FIPS variants requires a Docker
subscription — the tags return 401 without one.

The FIPS image runs with the following verified environment variables that enable FIPS mode:

- `GODEBUG=fips140=on` — enables FIPS 140 mode in the Go runtime
- `GOFIPS140=v1.0.0` — specifies the FIPS 140 Go module version
- `OPENSSL_CONF=/usr/lib/ssl/openssl.cnf` — points to the FIPS-enabled OpenSSL configuration
- `OPENSSL_MODULES=/usr/lib/aarch64-linux-gnu/ossl-modules` — path to OpenSSL FIPS modules
- `OPENSSL_VERSION=3.5.5` — OpenSSL version used

> **Note:** The following behaviours are documented from cert-manager source code. They cannot be tested without a
> Docker subscription, a FIPS-enabled Kubernetes cluster, and a live DNS server. Triggering these panics requires a full
> production FIPS environment.

When using FIPS variants, be aware of the following cert-manager behaviours involving non-FIPS-compliant algorithms:

1. **RFC2136 DNS-01 solver** — The
   [tsigHMACProvider.Generate](https://github.com/cert-manager/cert-manager/blob/master/pkg/issuer/acme/dns/rfc2136/tsig.go#L49)
   function uses SHA1 and MD5 for TSIG authentication, which are forbidden by FIPS and will cause the application to
   panic. To mitigate, specify a FIPS-approved algorithm in your `Issuer` or `ClusterIssuer`:

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

1. **Legacy TLS cipher suites** (RC4, ChaCha20, SHA1) — cert-manager includes these for compatibility with older DNS
   servers. They are supported but not preferred; modern clients negotiate stronger ciphers automatically.

1. **PKCS#12 legacy profiles** (DES and RC2) — cert-manager supports `LegacyDESPKCS12Profile` and
   `LegacyRC2PKCS12Profile` for backward compatibility. Use the
   [Modern 2023](https://github.com/cert-manager/cert-manager/blob/v1.19.1/pkg/apis/certmanager/v1/types_certificate.go#L536)
   Certificate profile as a FIPS-compliant alternative, or avoid keystores entirely.

1. **CHACHA20_POLY1305 cipher** — If the client supports `TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305`, the application will
   panic. Ensure your FIPS-compliant stack does not negotiate this cipher.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or Kubernetes manifests. At
minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This and a few other
common changes are listed in the following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile or Kubernetes manifests with a Docker Hardened Image.                                                                                                                                     |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                             |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                            |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                    |
| Ports              | Non-dev hardened images run as a nonroot user by default. cert-manager-webhook listens on port 6443 for HTTPS traffic by default (configurable via `--secure-port`), which works without issues.                                      |
| Entry point        | Docker Hardened Images may have different entry points than standard cert-manager images. The DHI entry point is `/app/cmd/webhook/webhook`. Inspect entry points for Docker Hardened Images and update your deployment if necessary. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                           |
| TLS configuration  | The webhook requires a valid TLS certificate and key at startup. Ensure your Deployment mounts the correct certificate files or references the CA Secret for dynamic generation.                                                      |

The following steps outline the general migration process.

1. **Find hardened images for your app.** The cert-manager-webhook hardened image may have several variants. Inspect the
   image tags and find the image variant that meets your needs. Remember that cert-manager requires multiple components
   to function properly.
1. **Update the image references in your Kubernetes manifests.** Update the image references in your cert-manager
   deployment manifests to use the hardened images. If using Helm, update your values file accordingly.
1. **For custom deployments, update the runtime image in your Dockerfile.** If you're building custom images based on
   cert-manager, ensure that your final image uses the hardened cert-manager-webhook as the base.
1. **Verify component compatibility.** Ensure all cert-manager components (controller, webhook, cainjector, acmesolver)
   are using compatible versions. The webhook works in conjunction with these other components.
1. **Test admission control.** After migration, test that cert-manager resources are correctly validated and mutated,
   and that API server communication with the webhook continues to function correctly.

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

cert-manager-webhook requires read and write access to the `cert-manager-webhook-ca` Secret for TLS certificate
generation, and requires `subjectaccessreviews` permissions for audit logging. Ensure your RBAC configuration grants
appropriate permissions.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 443:8443 my-image` will work because the port inside the container is 8443, and
`docker run -p 443:443 my-image` won't work because the port inside the container is 443.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than standard cert-manager images. Use `docker inspect` to
inspect entry points for Docker Hardened Images and update your Kubernetes deployment if necessary.
