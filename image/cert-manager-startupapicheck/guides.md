## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this cert-manager-startupapicheck image

This Docker Hardened cert-manager-startupapicheck image includes the post-install health check component of cert-manager
in a single, security-hardened package:

- **cert-manager-startupapicheck**: The `startupapicheck` binary that validates cert-manager API server endpoints and
  critical components are available and healthy before cert-manager begins normal operation
- **One-shot execution model**: Runs as a Kubernetes Job that exits 0 on success or non-zero on failure, making it
  suitable for Helm post-install hooks and CI/CD pipelines
- **In-cluster and out-of-cluster authentication**: Supports both in-cluster service account credentials and external
  kubeconfig files for cluster access
- **TLS support**: Standard TLS certificates are included for secure communication with the Kubernetes API

## Start a cert-manager-startupapicheck container

> **Note:** cert-manager-startupapicheck is designed to run inside a Kubernetes cluster as part of a full cert-manager
> deployment, typically as a Helm post-install Job. The following standalone Docker command displays the available
> configuration options.

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run --rm dhi.io/cert-manager-startupapicheck:<tag> --help
```

### Run with an external kubeconfig

When running outside a cluster, mount your kubeconfig and pass `--kubeconfig`:

```bash
docker run --rm \
  -v ~/.kube/config:/kube/config:ro \
  dhi.io/cert-manager-startupapicheck:<tag> \
  check api --kubeconfig /kube/config --wait 60s
```

> **Note:** Running outside a cluster against a local kubeconfig will fail unless cert-manager is already deployed and
> the Kubernetes API is reachable. The expected failure mode is a connection or API error, not a crash.

## Command-line flags

The `startupapicheck` binary accepts configuration via command-line flags. When running via Docker, commonly used flags
include:

| Flag           | Description                                                                          | Default          | Required                                |
| -------------- | ------------------------------------------------------------------------------------ | ---------------- | --------------------------------------- |
| `--kubeconfig` | Path inside the container to a kubeconfig file used to connect to the target cluster | none             | No — omit to use in-cluster credentials |
| `--wait`       | Duration to wait for cert-manager to become ready before failing                     | `0s` (poll once) | No                                      |
| `-v`, `--v`    | Log level verbosity (number)                                                         | `0`              | No                                      |

Example:

```bash
# Mount kubeconfig and pass via --kubeconfig flag
docker run --rm -v ~/.kube/config:/kube/config:ro \
  dhi.io/cert-manager-startupapicheck:<tag> \
  check api --kubeconfig /kube/config

# Enable verbose logging
docker run --rm dhi.io/cert-manager-startupapicheck:<tag> -v 2 --help
```

## Common cert-manager-startupapicheck use cases

### Validate cert-manager API availability

The primary purpose of `startupapicheck` is to verify that cert-manager's custom API resources are registered and the
webhook is reachable before post-install steps proceed. It probes the cert-manager API by attempting to create a
`CertificateRequest` resource and checking for a valid admission response.

When deployed via Helm, cert-manager automatically runs `startupapicheck` as a post-install Job. You can also run it
manually to verify a running cert-manager installation.

First, create the required service account and RBAC. This is handled automatically by Helm but must be created manually
when using `kubectl apply`:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager-startupapicheck
  namespace: cert-manager
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-manager-startupapicheck
rules:
  - apiGroups: ["cert-manager.io"]
    resources: ["certificaterequests"]
    verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-manager-startupapicheck
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-manager-startupapicheck
subjects:
  - kind: ServiceAccount
    name: cert-manager-startupapicheck
    namespace: cert-manager
EOF
```

Then run the Job:

```bash
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: cert-manager-startupapicheck
  namespace: cert-manager
spec:
  backoffLimit: 4
  template:
    spec:
      restartPolicy: OnFailure
      serviceAccountName: cert-manager-startupapicheck
      containers:
        - name: startupapicheck
          image: dhi.io/cert-manager-startupapicheck:<tag>
          args:
            - check
            - api
            - --wait=60s
          env:
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
EOF
```

A successful run produces output similar to:

```
The cert-manager API is ready
```

The Job exits 0 on success and the pod reaches `Completed` status.

### Use as a Helm post-install hook

In production deployments, `startupapicheck` runs automatically as a Helm post-install hook. When using the DHI Helm
chart, no extra configuration is required — the hook is pre-configured to use the DHI image. The hook blocks the
`helm install` command from returning until cert-manager is confirmed ready:

```bash
helm install my-cert-manager oci://dhi.io/cert-manager-chart --version 1.19.4 \
  --namespace cert-manager \
  --set "global.imagePullSecrets[0].name=helm-pull-secret" \
  --set "installCRDs=true"
```

If `startupapicheck` fails, the Helm installation is marked as failed and the release is rolled back.

### Monitor readiness in CI/CD pipelines

`startupapicheck` is useful as a readiness gate in CI/CD pipelines after deploying cert-manager. Run the Job and wait
for its completion before proceeding with certificate issuance steps:

```bash
# Wait for the startupapicheck Job to complete
kubectl wait --for=condition=complete \
  job/cert-manager-startupapicheck \
  -n cert-manager --timeout=120s

# Then proceed with certificate issuance
kubectl apply -f my-certificate.yaml
```

## End-to-end startupapicheck deployment walkthrough

The following steps demonstrate a complete deployment and verification, validated against cert-manager v1.19.4 and
`dhi.io/cert-manager-startupapicheck:1-debian13`.

**Prerequisites:** A running Kubernetes cluster with `kubectl` and `helm` access. All cert-manager components must use
Docker Hardened Images. The recommended way to install all components together is via the DHI Helm chart, which deploys
`dhi.io/cert-manager-controller`, `dhi.io/cert-manager-cainjector`, `dhi.io/cert-manager-webhook`,
`dhi.io/cert-manager-startupapicheck`, and `dhi.io/cert-manager-acmesolver` automatically:

```bash
# Create the namespace and imagePullSecret first
kubectl create namespace cert-manager

kubectl create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<your-docker-username> \
  --docker-password=<your-docker-password> \
  -n cert-manager

# Install all cert-manager components using the DHI Helm chart
helm install my-cert-manager oci://dhi.io/cert-manager-chart --version 1.19.4 \
  --namespace cert-manager \
  --set "global.imagePullSecrets[0].name=helm-pull-secret" \
  --set "installCRDs=true"

# Wait for all pods to be ready
kubectl wait --for=condition=Ready pod --all -n cert-manager --timeout=120s
```

**Step 1: Verify the startupapicheck Job ran and completed**

```bash
kubectl get job -n cert-manager | grep startupapicheck
# NAME                                    COMPLETIONS   DURATION   AGE
# my-cert-manager-startupapicheck         1/1           12s        2m
```

**Step 2: Inspect the Job logs**

```bash
kubectl logs job/my-cert-manager-startupapicheck -n cert-manager
# The cert-manager API is ready
```

> **Note:** When deployed via Helm with `installCRDs=true`, the `startupapicheck` Job first polls while cainjector
> injects the webhook CA bundle. You may see repeated `"Not ready"` messages referencing
> `x509: certificate signed by unknown authority` for 60–90 seconds before the Job completes. This is expected behavior.
> Once cainjector finishes CA injection, the Job completes and is automatically cleaned up by Helm.

**Step 3: Confirm the DHI image is in use**

```bash
kubectl get job my-cert-manager-startupapicheck -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# dhi.io/cert-manager-startupapicheck:1-debian13
```

**Step 4: Run a standalone check against the live cluster**

```bash
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: startupapicheck-manual
  namespace: cert-manager
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: OnFailure
      serviceAccountName: my-cert-manager-startupapicheck
      containers:
        - name: startupapicheck
          image: dhi.io/cert-manager-startupapicheck:1-debian13
          args:
            - check
            - api
            - --wait=60s
          env:
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
EOF

kubectl wait --for=condition=complete \
  job/startupapicheck-manual \
  -n cert-manager --timeout=120s
```

Expected: `job.batch/startupapicheck-manual condition met`

**Step 5: Clean up**

```bash
kubectl delete job startupapicheck-manual -n cert-manager
kubectl delete clusterrolebinding cert-manager-startupapicheck
kubectl delete clusterrole cert-manager-startupapicheck
kubectl delete serviceaccount cert-manager-startupapicheck -n cert-manager
helm uninstall my-cert-manager -n cert-manager
kubectl delete secret helm-pull-secret -n cert-manager
kubectl delete namespace cert-manager

# CRDs are kept by Helm resource policy — delete manually if needed
kubectl delete crd \
  challenges.acme.cert-manager.io \
  orders.acme.cert-manager.io \
  certificaterequests.cert-manager.io \
  certificates.cert-manager.io \
  clusterissuers.cert-manager.io \
  issuers.cert-manager.io
```

## Official images vs Docker Hardened Images

| Feature             | DOI (`quay.io/jetstack/cert-manager-startupapicheck`) | DHI (`dhi.io/cert-manager-startupapicheck`)         |
| ------------------- | ----------------------------------------------------- | --------------------------------------------------- |
| User                | `1000` (numeric UID)                                  | `nonroot` / UID 65532 (runtime/FIPS) / `root` (dev) |
| Shell               | None                                                  | No (runtime/FIPS) / Yes (dev)                       |
| Package manager     | None                                                  | No (runtime/FIPS) / APT (dev)                       |
| Binary path         | `/startupapicheck`                                    | `/usr/local/bin/startupapicheck`                    |
| Entrypoint          | `["/startupapicheck"]`                                | `["/usr/local/bin/startupapicheck"]`                |
| Zero CVE commitment | No                                                    | Yes                                                 |
| FIPS variant        | No                                                    | Yes (FIPS + STIG + CIS)                             |
| Base OS             | Distroless (Google)                                   | Docker Hardened Images (Debian 13)                  |
| Signed provenance   | No                                                    | Yes                                                 |
| SBOM / VEX metadata | No                                                    | Yes                                                 |
| Compliance labels   | None                                                  | CIS (runtime), FIPS+STIG+CIS (fips)                 |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- **Runtime variants** are designed to run `startupapicheck` in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the binary

- **Build-time variants** typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

> **Note:** cert-manager consists of multiple components (controller, acmesolver, cainjector, webhook, startupapicheck)
> that work together. Each component is available as a separate Docker Hardened Image for deployment flexibility.

## FIPS variants considerations

FIPS variants (`1-fips`, `1-debian13-fips`, `1.19-fips`, `1.19.4-fips`, `1.19.4-debian13-fips`) are available on Docker
Hub and carry CIS, FIPS, and STIG compliance badges with 0 vulnerabilities. Pulling FIPS variants requires a Docker
subscription — the tags return 401 without one.

The FIPS image runs with the following environment variables that enable FIPS mode:

- `GODEBUG=fips140=on` — enables FIPS 140 mode in the Go runtime
- `GOFIPS140=v1.0.0` — specifies the FIPS 140 Go module version
- `OPENSSL_CONF=/usr/lib/ssl/openssl.cnf` — points to the FIPS-enabled OpenSSL configuration
- `OPENSSL_MODULES=/usr/lib/aarch64-linux-gnu/ossl-modules` — path to OpenSSL FIPS modules
- `OPENSSL_VERSION=3.5.5` — OpenSSL version used

> **Note:** The following behaviours are documented from cert-manager source code. They cannot be tested without a
> Docker subscription, a FIPS-enabled Kubernetes cluster, and a live DNS server.

When using FIPS variants, be aware of the following cert-manager behaviours involving non-FIPS-compliant algorithms:

1. **RFC2136 DNS-01 solver** — The `tsigHMACProvider.Generate` function uses SHA1 and MD5 for TSIG authentication, which
   are forbidden by FIPS and will cause the application to panic. To mitigate, specify a FIPS-approved algorithm in your
   `Issuer` or `ClusterIssuer`:

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
minimum, update the base image in your existing deployment to a Docker Hardened Image. Common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                     |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile or Kubernetes manifests with a Docker Hardened Image.                                                                                  |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                        |
| Non-root user      | By default, non-dev images run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                         |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                 |
| Ports              | `startupapicheck` does not bind to any network ports — it makes outbound connections to the Kubernetes API only. Privileged port restrictions do not apply to this component.      |
| Entry point        | Docker Hardened Images may have different entry points than standard cert-manager images. Inspect entry points for Docker Hardened Images and update your deployment if necessary. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.        |

The following steps outline the general migration process.

1. **Find hardened images for your app.** The `cert-manager-startupapicheck` hardened image may have several variants.
   Inspect the image tags and find the image variant that meets your needs. Remember that cert-manager requires multiple
   components to function properly.

1. **Update the image reference in your Helm values or Kubernetes manifests.** If using Helm, set the image in your
   `values.yaml`:

   ```yaml
   startupapicheck:
     image:
       repository: dhi.io/cert-manager-startupapicheck
       tag: "<tag>"
   ```

1. **For custom Dockerfiles, update the runtime image.** Ensure all stages in your Dockerfile use hardened images.
   Intermediary stages typically use `dev`-tagged images; your final runtime stage should use a non-dev image variant.

1. **Verify component compatibility.** Ensure all cert-manager components (controller, webhook, cainjector, acmesolver,
   startupapicheck) are using compatible versions. The startupapicheck Job runs after all other components are deployed.

1. **Confirm the check passes.** After migration, inspect the completed Job logs to confirm
   `The cert-manager API is ready` appears in the output.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default, image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user.

`cert-manager-startupapicheck` requires `create` permission on `certificaterequests` in the `cert-manager.io` API group
to probe API availability. Ensure your RBAC configuration grants the `cert-manager-startupapicheck` service account this
permission.

### Privileged ports

`startupapicheck` does not bind to any network ports — it only makes outbound connections to the Kubernetes API server.
Privileged port restrictions do not apply to this component.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than standard cert-manager images. Use `docker inspect` to
inspect entry points for Docker Hardened Images and update your Kubernetes deployment if necessary.
