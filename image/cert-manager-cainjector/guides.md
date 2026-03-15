## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this cert-manager-cainjector image

This Docker Hardened cert-manager-cainjector image includes the cainjector component of cert-manager in a single,
security-hardened package:

- `cert-manager-cainjector`: The CA injector binary that automatically injects CA certificate data into Kubernetes
  webhook configurations and API services
- CA bundle injection capabilities for Mutating Webhooks, Validating Webhooks, Conversion Webhooks, and API Services
- Support for injecting CA data from Certificate resources, Secret resources, or the Kubernetes API server CA
- Automatic population of `caBundle` fields to help the Kubernetes API server verify serving certificates

## Start a cert-manager-cainjector image

> **Note:** cert-manager-cainjector is designed to run within a Kubernetes cluster to inject CA certificate data into
> webhook configurations. The following standalone Docker command displays the available configuration options.

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run --rm dhi.io/cert-manager-cainjector:<tag> --help
```

### Configure injection sources

The cainjector can inject CA data from three sources:

- Certificate resources (using `cert-manager.io/inject-ca-from` annotation)
- Secret resources (using `cert-manager.io/inject-ca-from-secret` annotation)
- Kubernetes API server CA (using `cert-manager.io/inject-apiserver-ca` annotation)

These injection sources can be controlled through annotations on target resources.

### Configure namespace filtering

The `--namespace` flag restricts the cainjector to only watch resources in a SINGLE namespace. By default, it watches
all namespaces.

```bash
docker run --rm dhi.io/cert-manager-cainjector:<tag> \
  --namespace=cert-manager
```

## Common cert-manager-cainjector use cases

### Inject CA certificates into webhook configurations

The cainjector automatically populates CA bundles for Kubernetes admission webhooks to enable secure communication
between the API server and webhook endpoints.

The following example shows a ValidatingWebhookConfiguration with CA injection annotation:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: my-webhook
  annotations:
    cert-manager.io/inject-ca-from: webhook-ns/webhook-certificate
webhooks:
- name: webhook.example.com
  admissionReviewVersions: ["v1"]
  sideEffects: None
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

You can inject CA data directly from Kubernetes Secrets using the `inject-ca-from-secret` annotation. Two requirements
must be met for this to work:

1. The Secret must have the annotation `cert-manager.io/allow-direct-injection: "true"` — without this, cainjector
   refuses to inject from the Secret regardless of its contents.
1. The Secret must store the CA certificate under the key `ca.crt` — other key names (such as `tls.crt`) are not
   recognised by cainjector.

Create the Secret with the correct key and annotation:

```bash
# Generate a self-signed CA cert
openssl req -x509 -newkey rsa:2048 -keyout ca.key -out ca.crt \
  -days 365 -nodes -subj "/CN=my-ca.example.com"

# Create the Secret with the required ca.crt key
kubectl create secret generic ca-secret \
  --from-file=ca.crt=ca.crt \
  -n webhook-ns

# Add the required annotation to allow direct injection
kubectl annotate secret ca-secret -n webhook-ns \
  'cert-manager.io/allow-direct-injection=true'
```

Then create the `MutatingWebhookConfiguration` referencing the Secret:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: my-mutating-webhook
  annotations:
    cert-manager.io/inject-ca-from-secret: webhook-ns/ca-secret
webhooks:
- name: mutate.example.com
  admissionReviewVersions: ["v1"]
  sideEffects: None
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-ns
      path: /mutate
    # caBundle will be populated from the ca.crt key in ca-secret
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

Verify the injection:

```bash
kubectl get mutatingwebhookconfiguration my-mutating-webhook \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' \
  | base64 -d \
  | openssl x509 -text -noout \
  | grep -E "Subject:|Issuer:|Not After"
```

Expected output:

```
        Issuer: CN=my-ca.example.com
            Not After : Mar 11 20:54:35 2027 GMT
        Subject: CN=my-ca.example.com
```

### End-to-end CA injection walkthrough

The following steps demonstrate a complete CA injection workflow, validated against cert-manager v1.19.4 and
`dhi.io/cert-manager-cainjector:1-debian13`.

**Prerequisites**: cert-manager must be installed and all three pods (cert-manager, cert-manager-cainjector,
cert-manager-webhook) must be `Ready` before proceeding.

**Step 1: Install cert-manager**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.4/cert-cert-manager.yaml
```

Wait for all pods to be ready:

```bash
kubectl wait --for=condition=Ready pod --all -n cert-manager --timeout=120s
```

**Step 2: Create a namespace and a self-signed Issuer**

```bash
kubectl create namespace webhook-ns

kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
  namespace: webhook-ns
spec:
  selfSigned: {}
EOF
```

**Step 3: Create a Certificate**

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: webhook-certificate
  namespace: webhook-ns
spec:
  secretName: webhook-certificate-tls
  issuerRef:
    name: selfsigned-issuer
    kind: Issuer
  commonName: webhook.example.com
  dnsNames:
  - webhook.example.com
  isCA: true
EOF
```

Wait for the certificate to be issued:

```bash
kubectl get certificate -n webhook-ns
# NAME                  READY   SECRET                    AGE
# webhook-certificate   True    webhook-certificate-tls   12s
```

**Step 4: Create a ValidatingWebhookConfiguration with the inject-ca-from annotation**

```bash
kubectl apply -f - <<'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: my-webhook
  annotations:
    cert-manager.io/inject-ca-from: webhook-ns/webhook-certificate
webhooks:
- name: webhook.example.com
  admissionReviewVersions: ["v1"]
  sideEffects: None
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
EOF
```

**Step 5: Verify CA injection**

Within seconds, the cainjector detects the annotation and populates the `caBundle` field. Verify the injection:

```bash
kubectl get validatingwebhookconfiguration my-webhook \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' \
  | base64 -d \
  | openssl x509 -text -noout \
  | grep -E "Subject:|Issuer:|Not After"
```

Expected output:

```
        Issuer: CN=webhook.example.com
            Not After : Jun  9 20:46:11 2026 GMT
        Subject: CN=webhook.example.com
```

A non-empty `caBundle` with the expected issuer confirms that cainjector is running correctly and injecting CA data
automatically.

**Step 6: Confirm injection in cainjector logs**

```bash
kubectl logs -n cert-manager -l app=cainjector --tail=20 | grep "Updated object"
# I0311 20:46:41.193241  1 reconciler.go:141] "Updated object" ... kind="validatingwebhookconfiguration" name="my-webhook"
```

**Step 7: Clean up**

```bash
kubectl delete validatingwebhookconfiguration my-webhook
kubectl delete certificate webhook-certificate -n webhook-ns
kubectl delete issuer selfsigned-issuer -n webhook-ns
kubectl delete namespace webhook-ns
```

### End-to-end inject-ca-from-secret walkthrough

The following steps demonstrate CA injection directly from a Secret resource, validated against cert-manager v1.19.4.
This approach is useful when you manage certificates outside of cert-manager.

**Step 1: Create namespace and generate a CA certificate**

```bash
kubectl create namespace webhook-ns

openssl req -x509 -newkey rsa:2048 -keyout ca.key -out ca.crt \
  -days 365 -nodes -subj "/CN=my-ca.example.com"
```

**Step 2: Create the Secret with the correct key name and annotation**

The Secret must use `ca.crt` as the key name (not `tls.crt`) and must have the
`cert-manager.io/allow-direct-injection: "true"` annotation. Without either of these, cainjector will refuse to inject.

```bash
kubectl create secret generic ca-secret \
  --from-file=ca.crt=ca.crt \
  -n webhook-ns

kubectl annotate secret ca-secret -n webhook-ns \
  'cert-manager.io/allow-direct-injection=true'
```

**Step 3: Create a MutatingWebhookConfiguration with the inject-ca-from-secret annotation**

```bash
kubectl apply -f - <<'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: my-mutating-webhook
  annotations:
    cert-manager.io/inject-ca-from-secret: webhook-ns/ca-secret
webhooks:
- name: mutate.example.com
  admissionReviewVersions: ["v1"]
  sideEffects: None
  clientConfig:
    service:
      name: webhook-service
      namespace: webhook-ns
      path: /mutate
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
EOF
```

**Step 4: Verify CA injection**

```bash
kubectl get mutatingwebhookconfiguration my-mutating-webhook \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' \
  | base64 -d \
  | openssl x509 -text -noout \
  | grep -E "Subject:|Issuer:|Not After"
```

Expected output:

```
        Issuer: CN=my-ca.example.com
            Not After : Mar 11 20:54:35 2027 GMT
        Subject: CN=my-ca.example.com
```

**Step 5: Confirm in cainjector logs**

```bash
kubectl logs -n cert-manager -l app=cainjector --tail=10 | grep "Updated object"
# I0311 20:58:23.231001  1 reconciler.go:141] "Updated object" ... kind="mutatingwebhookconfiguration" name="my-mutating-webhook"
```

**Step 6: Clean up**

```bash
kubectl delete mutatingwebhookconfiguration my-mutating-webhook
kubectl delete secret ca-secret -n webhook-ns
kubectl delete namespace webhook-ns
rm -f ca.crt ca.key
```

### Deploy cert-manager-cainjector in Kubernetes

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

The cainjector is typically deployed as part of a complete cert-manager installation in Kubernetes. It requires a
ServiceAccount with cluster-scoped RBAC permissions to read CRDs, Certificates, and Secrets, and to update webhook
configurations and APIServices.

**Step 1: Create the namespace and imagePullSecret**

```bash
kubectl create namespace cert-manager

kubectl create secret docker-registry dhi-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<your-docker-username> \
  --docker-password=<your-docker-password> \
  -n cert-manager
```

**Step 2: Create the ServiceAccount and RBAC**

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cainjector
  namespace: cert-manager
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cainjector-role
rules:
- apiGroups: ["cert-manager.io"]
  resources: ["certificates"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["validatingwebhookconfigurations", "mutatingwebhookconfigurations"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: ["apiregistration.k8s.io"]
  resources: ["apiservices"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: [""]
  resources: ["secrets", "configmaps", "events"]
  verbs: ["get", "list", "watch", "create", "patch", "update"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "create", "update", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cainjector-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cainjector-role
subjects:
- kind: ServiceAccount
  name: cainjector
  namespace: cert-manager
EOF
```

**Step 3: Deploy cert-manager-cainjector**

> **Note:** The `--cluster-resource-namespace` flag does not exist in this version. Use `--leader-election-namespace`
> instead, populated via the `POD_NAMESPACE` environment variable from the pod's own namespace using the Downward API.

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-manager-cainjector
  namespace: cert-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cert-manager-cainjector
  template:
    metadata:
      labels:
        app: cert-manager-cainjector
    spec:
      serviceAccountName: cainjector
      containers:
      - name: cert-manager-cainjector
        image: dhi.io/cert-manager-cainjector:<tag>
        args:
        - --v=2
        - --leader-election-namespace=$(POD_NAMESPACE)
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
      imagePullSecrets:
      - name: dhi-pull-secret
EOF
```

**Step 4: Verify the deployment**

```bash
kubectl get pods -n cert-manager
# NAME                                    READY   STATUS    RESTARTS   AGE
# cert-manager-cainjector-xxx             1/1     Running   0          20s

kubectl logs -n cert-manager deployment/cert-manager-cainjector | grep -E "Starting|Updated|leader"
# I0312 07:10:35  "starting cert-manager ca-injector" version="1.19.4"
# I0312 07:10:35  became leader
# I0312 07:10:35  "Starting Controller" controller="validatingwebhookconfiguration"
# I0312 07:10:35  "Starting Controller" controller="mutatingwebhookconfiguration"
# I0312 07:10:35  "Starting Controller" controller="customresourcedefinition"
# I0312 07:10:35  "Starting Controller" controller="apiservice"
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

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

**Note:** cert-manager consists of multiple components (controller, acmesolver, cainjector, webhook) that work together.
Each component may be available as a separate Docker Hardened Image for deployment flexibility.

### FIPS variants considerations

FIPS variants (`1-fips`, `1-debian13-fips`, `1.19-fips`, `1.19.4-fips`, `1.19.4-debian13-fips`) are available on Docker
Hub and carry CIS, FIPS, and STIG compliance badges with 0 vulnerabilities. Pulling FIPS variants requires a Docker
subscription — the tags return 401 without one.

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

| Item               | Migration note                                                                                                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile or Kubernetes manifests with a Docker Hardened Image.                                                                                  |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                          |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                         |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                             |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                 |
| Ports              | Non-dev hardened images run as a nonroot user by default. cert-manager-cainjector uses port 9402 for metrics (default: `0.0.0.0:9402`), which works without issues.                |
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
1. **Verify component compatibility.** Ensure all cert-manager components (controller, webhook, cainjector, acmesolver)
   are using compatible versions. The cainjector works in conjunction with these other components.
1. **Test CA injection.** After migration, test that webhook configurations are properly receiving CA bundle injections
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
