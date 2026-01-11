## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- **Public image**: `dhi.io/vault-k8s:<tag>`
- **Mirrored image**: `<your-namespace>/dhi-vault-k8s:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Vault K8s instance

Vault K8s is designed to work with HashiCorp Vault in Kubernetes environments. It provides the agent-inject
functionality that automatically injects secrets from Vault into pods.

### Deploy Vault Server

First, deploy a Vault server in dev mode for testing. In production, you would use a properly configured Vault instance.

```bash
# Create namespace
kubectl create namespace vault

# Deploy Vault server in dev mode
cat > vault-server.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault
  namespace: vault
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: vault
spec:
  ports:
  - name: vault
    port: 8200
    targetPort: 8200
  selector:
    app: vault
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: vault
spec:
  serviceName: vault
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      serviceAccountName: vault
      containers:
      - name: vault
        image: hashicorp/vault:1.21.1
        args:
        - server
        - -dev
        - -dev-root-token-id=root
        - -dev-listen-address=0.0.0.0:8200
        env:
        - name: VAULT_DEV_ROOT_TOKEN_ID
          value: "root"
        - name: VAULT_ADDR
          value: "http://127.0.0.1:8200"
        ports:
        - containerPort: 8200
          name: vault
        readinessProbe:
          httpGet:
            path: /v1/sys/health
            port: 8200
          initialDelaySeconds: 5
EOF

kubectl apply -f vault-server.yaml

# Wait for Vault to be ready
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=60s
```

### Deploy Vault K8s Agent Injector

The vault-agent-injector operates as a Kubernetes Mutating Admission Webhook. Kubernetes requires all admission webhooks
to use HTTPS/TLS for security - this is not optional, it's a Kubernetes requirement.

Let's generate TLS certificates and deploy the Vault K8s agent injector.

```bash
# Generate TLS certificates for the webhook
SERVICE_NAME=vault-agent-injector-svc
NAMESPACE=vault
SECRET_NAME=vault-agent-injector-certs
TMPDIR=$(mktemp -d)
openssl genrsa -out ${TMPDIR}/tls.key 2048
openssl req -new -x509 -key ${TMPDIR}/tls.key -out ${TMPDIR}/tls.crt -days 365 \
    -subj "/CN=${SERVICE_NAME}.${NAMESPACE}.svc" \
    -addext "subjectAltName=DNS:${SERVICE_NAME}.${NAMESPACE}.svc,DNS:${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"
kubectl create secret tls ${SECRET_NAME} \
    --cert=${TMPDIR}/tls.crt \
    --key=${TMPDIR}/tls.key \
    -n ${NAMESPACE}
rm -rf ${TMPDIR}

# Deploy Vault K8s Agent Injector with DHI
cat > vault-agent-injector.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-agent-injector
  namespace: vault
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: vault-agent-injector
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - mutatingwebhookconfigurations
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-agent-injector
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: vault-agent-injector
subjects:
- kind: ServiceAccount
  name: vault-agent-injector
  namespace: vault
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-agent-injector
  namespace: vault
  labels:
    app: vault-agent-injector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault-agent-injector
  template:
    metadata:
      labels:
        app: vault-agent-injector
    spec:
      serviceAccountName: vault-agent-injector
      containers:
      - name: vault-agent-injector
        image: <your-namespace>/vault-k8s:<tag>
        args:
        - agent-inject
        - -vault-address=http://vault.vault.svc:8200
        - -listen=:8080
        - -tls-cert-file=/etc/webhook/certs/tls.crt
        - -tls-key-file=/etc/webhook/certs/tls.key
        ports:
        - name: https
          containerPort: 8080
        volumeMounts:
        - name: webhook-certs
          mountPath: /etc/webhook/certs
          readOnly: true
      volumes:
      - name: webhook-certs
        secret:
          secretName: vault-agent-injector-certs
---
apiVersion: v1
kind: Service
metadata:
  name: vault-agent-injector-svc
  namespace: vault
spec:
  ports:
  - name: https
    port: 443
    targetPort: 8080
  selector:
    app: vault-agent-injector
EOF

kubectl apply -f vault-agent-injector.yaml
```

### Update webhook configuration

If you have an existing MutatingWebhookConfiguration, update it with the new CA bundle:

```bash
# Update the webhook with the new CA certificate
CA_BUNDLE=$(kubectl get secret vault-agent-injector-certs -n vault -o jsonpath='{.data.tls\.crt}')
kubectl patch mutatingwebhookconfiguration vault-agent-injector-cfg --type='json' -p="[
  {
    \"op\": \"replace\",
    \"path\": \"/webhooks/0/clientConfig/caBundle\",
    \"value\": \"${CA_BUNDLE}\"
  }
]" 2>/dev/null || echo "No existing webhook configuration to update"
```

### Verify the deployment

```bash
kubectl get pods -n vault
kubectl logs -n vault -l app=vault-agent-injector
```

## Common Vault K8s use cases

### Configure Vault authentication

Set up Kubernetes authentication for Vault.

```bash
# Enable Kubernetes auth in Vault
kubectl exec -n vault vault-0 -- sh -c 'VAULT_TOKEN=root vault auth enable kubernetes'

# Configure Kubernetes auth
KUBE_HOST=$(kubectl exec -n vault vault-0 -- sh -c 'echo $KUBERNETES_SERVICE_HOST')
KUBE_PORT=$(kubectl exec -n vault vault-0 -- sh -c 'echo $KUBERNETES_SERVICE_PORT')

kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=root vault write auth/kubernetes/config \
    kubernetes_host='https://${KUBE_HOST}:${KUBE_PORT}' \
    disable_local_ca_jwt=false"

# Create a test secret
kubectl exec -n vault vault-0 -- sh -c 'VAULT_TOKEN=root vault kv put secret/database/config \
    username="db-user" \
    password="db-password"'

# Create a policy
cat > /tmp/webapp-policy.hcl << 'EOF'
path "secret/data/database/config" {
  capabilities = ["read"]
}
EOF
kubectl cp /tmp/webapp-policy.hcl vault/vault-0:/tmp/webapp-policy.hcl
kubectl exec -n vault vault-0 -- sh -c 'VAULT_TOKEN=root vault policy write webapp /tmp/webapp-policy.hcl'

# Create service account for the application
kubectl create serviceaccount webapp -n default

# Create role
kubectl exec -n vault vault-0 -- sh -c 'VAULT_TOKEN=root vault write auth/kubernetes/role/webapp \
    bound_service_account_names=webapp \
    bound_service_account_namespaces=default \
    policies=webapp \
    ttl=24h'
```

### Inject secrets into application pods

Annotate your application pods to automatically inject Vault secrets.

```yaml
cat > app-with-secrets.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: webapp
  namespace: default
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "webapp"
    vault.hashicorp.com/agent-inject-secret-database-config: "secret/data/database/config"
    vault.hashicorp.com/agent-inject-template-database-config: |
      {{- with secret "secret/data/database/config" -}}
      postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@postgres:5432/mydb
      {{- end }}
spec:
  serviceAccountName: webapp
  containers:
  - name: webapp
    image: nginx:latest
    ports:
    - containerPort: 8080
EOF

kubectl apply -f app-with-secrets.yaml
```

### Verify secret injection

Once the pod is running, verify the secret was injected:

```bash
# Wait for pod to be ready
kubectl wait --for=condition=ready pod webapp -n default --timeout=60s

# Check the injected secret
kubectl exec webapp -n default -c webapp -- cat /vault/secrets/database-config
```

You should see the rendered template with the actual credentials:

```
postgresql://db-user:db-password@postgres:5432/mydb
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature                  | Standard Vault K8s                     | Docker Hardened Vault K8s                   |
| ------------------------ | -------------------------------------- | ------------------------------------------- |
| **Security**             | Standard minimal base                  | Hardened base with security patches         |
| **Shell access**         | No shell in runtime variants           | No shell in runtime variants                |
| **Package manager**      | No package manager in runtime variants | No package manager in runtime variants      |
| **User**                 | Runs as `vault` user                   | Runs as `nonroot` user (UID 65532)          |
| **Image size (runtime)** | ~35 MB (uncompressed)                  | ~12 MB (uncompressed) - 67% smaller         |
| **Attack surface**       | Minimal binaries and libraries         | Further minimized with additional hardening |
| **Debugging**            | Use Docker Debug or kubectl debug      | Use Docker Debug or kubectl debug           |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- **Docker Debug** to attach to containers
- **Docker's Image Mount feature** to mount debugging tools
- **Kubernetes-specific debugging** with `kubectl debug`

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For Kubernetes environments, you can use kubectl debug:

```bash
kubectl debug -n vault pod/<pod-name> -it --image=busybox --target=vault-agent-injector
```

Or use Docker Debug if you have access to the node:

```bash
docker debug <container-id>
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Runtime variants** are designed to run your application in production. These images are intended to be used either
directly or as the FROM image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

**Build-time variants** typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

The Vault K8s Docker Hardened Image is available in both runtime and dev variants. Use `dev` variants for building
custom configurations or extensions, and runtime variants for production deployments.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item                 | Migration note                                                                                                                                                                                                    |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Base image**       | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                         |
| **Non-root user**    | By default, images run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                       |
| **TLS certificates** | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                |
| **Ports**            | Hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. |
| **Entry point**      | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                       |

The following steps outline the general migration process.

1. **Find hardened images for your app.** A hardened image may have several variants. Inspect the image tags and find
   the image variant that meets your needs.

1. **Update the base image in your Dockerfile.** Update the base image in your application's Dockerfile to the hardened
   image you found in the previous step.

1. **Verify permissions** Since the image runs as nonroot user, ensure that data directories and mounted volumes are
   accessible to the nonroot user.

## Troubleshoot migration

### General debugging

The recommended method for debugging applications built with Docker Hardened Images is to use **Docker Debug** to attach
to these containers. Docker Debug provides a shell, common debugging tools, and lets you install other tools in an
ephemeral, writable layer that only exists during the debugging session.

### Permissions

By default image variants run as the nonroot user. Ensure that necessary files and directories are accessible to the
nonroot user. You may need to copy files to different directories or change permissions so your application running as
the nonroot user can access them.

### Privileged ports

Hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged
ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
