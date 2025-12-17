## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use docker `login dhi.io` to authenticate to the registry to pull the images.

## Start a ClickHouse Metrics Exporter instance

The ClickHouse Metrics Exporter is designed to work as part of the ClickHouse Operator in Kubernetes. It automatically
discovers and monitors ClickHouse clusters managed by the ClickHouse Operator, providing comprehensive operational
metrics through a standard `/metrics` endpoint for Prometheus scraping.

This image cannot run as a standalone container outside of Kubernetes as it requires access to the Kubernetes API and
ClickHouseInstallation custom resources.

### Deploy ClickHouse Operator (DHI)

First, deploy the ClickHouse Operator using the Docker Hardened Image. Replace `<tag>` with the image variant you want
to run.

```bash
cat > clickhouse-operator.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: clickhouse-operator
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: clickhouse-operator
rules:
- apiGroups:
  - clickhouse.altinity.com
  resources:
  - clickhouseinstallations
  - clickhouseinstallationtemplates
  - clickhouseoperatorconfigurations
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - ""
  resources:
  - configmaps
  - services
  - persistentvolumeclaims
  - secrets
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: clickhouse-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: clickhouse-operator
subjects:
- kind: ServiceAccount
  name: clickhouse-operator
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clickhouse-operator
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: clickhouse-operator
  template:
    metadata:
      labels:
        app: clickhouse-operator
    spec:
      serviceAccountName: clickhouse-operator
      containers:
      - name: clickhouse-operator
        image: dhi.io/clickhouse-operator:<tag>
        imagePullPolicy: Always
        env:
        - name: OPERATOR_POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: OPERATOR_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
EOF

kubectl apply -f clickhouse-operator.yaml
```

### Deploy Metrics Exporter (DHI)

Deploy the metrics exporter using the Docker Hardened Image. Replace `<tag>` with the image variant you want to run.

```bash
cat > clickhouse-metrics-exporter.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clickhouse-operator-metrics
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: clickhouse-operator-metrics
  template:
    metadata:
      labels:
        app: clickhouse-operator-metrics
    spec:
      serviceAccountName: clickhouse-operator
      containers:
      - name: metrics-exporter
        image: dhi.io/clickhouse-metrics-exporter:<tag>
        ports:
        - name: metrics
          containerPort: 8888
        args:
        - "-metrics-endpoint=:8888"
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: clickhouse-operator-metrics
  namespace: kube-system
spec:
  ports:
  - name: metrics
    port: 8888
    targetPort: 8888
  selector:
    app: clickhouse-operator-metrics
EOF

kubectl apply -f clickhouse-metrics-exporter.yaml
```

### Deploy a ClickHouse Cluster

Deploy a ClickHouse cluster for the metrics exporter to monitor.

```bash
# Create the namespace first
kubectl create namespace clickhouse-system

cat > clickhouse-cluster.yaml << 'EOF'
apiVersion: clickhouse.altinity.com/v1
kind: ClickHouseInstallation
metadata:
  name: my-cluster
  namespace: clickhouse-system
spec:
  configuration:
    users:
      clickhouse_operator/password: your-secure-password
      clickhouse_operator/networks/ip:
        - "0.0.0.0/0"
      clickhouse_operator/profile: default
    clusters:
      - name: production
        layout:
          shardsCount: 1
          replicasCount: 1
EOF

kubectl apply -f clickhouse-cluster.yaml
```

Verify the deployment:

```bash
kubectl get pods -n clickhouse-system
kubectl get pods -n kube-system -l app=clickhouse-operator-metrics
kubectl logs -n kube-system -l app=clickhouse-operator-metrics
```

## Common ClickHouse Metrics Exporter use cases

### Integrate with Prometheus using ServiceMonitor

Create a ServiceMonitor for Prometheus Operator to automatically scrape metrics from the exporter.

**Note:** This requires [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator) to be
installed in your cluster to provide the ServiceMonitor CRD.

```bash
cat > servicemonitor.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: clickhouse-operator-metrics
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: clickhouse-operator-metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
EOF

kubectl apply -f servicemonitor.yaml
```

### Configure ClickHouse authentication

Configure the `clickhouse_operator` user in your ClickHouseInstallation to allow the exporter to query ClickHouse
metrics.

```bash
cat > clickhouse-with-auth.yaml << 'EOF'
apiVersion: clickhouse.altinity.com/v1
kind: ClickHouseInstallation
metadata:
  name: my-cluster
  namespace: clickhouse-system
spec:
  configuration:
    users:
      clickhouse_operator/password: your-secure-password
      clickhouse_operator/networks/ip:
        - "0.0.0.0/0"
      clickhouse_operator/profile: default
    clusters:
      - name: production
        layout:
          shardsCount: 2
          replicasCount: 2
EOF

kubectl apply -f clickhouse-with-auth.yaml
```

### Mount custom configuration

Mount a custom ClickHouse Operator configuration file to modify exporter behavior.

```bash
cat > custom-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: clickhouse-operator-config
  namespace: kube-system
data:
  config.yaml: |
    clickhouse:
      configuration:
        users:
          default/networks/ip: "::/0"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clickhouse-operator-metrics
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: metrics-exporter
        image: dhi.io/clickhouse-metrics-exporter:<tag>
        args:
        - "-metrics-endpoint=:8888"
        - "-config=/etc/clickhouse-operator/config.yaml"
        volumeMounts:
        - name: config
          mountPath: /etc/clickhouse-operator
      volumes:
      - name: config
        configMap:
          name: clickhouse-operator-config
EOF

kubectl apply -f custom-config.yaml
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Standard ClickHouse Metrics Exporter         | Docker Hardened ClickHouse Metrics Exporter           |
| --------------- | -------------------------------------------- | ----------------------------------------------------- |
| Security        | Standard base with bash, curl, and utilities | Minimal, hardened base with security patches          |
| Shell access    | Full shell (bash/sh) available               | No shell in runtime variants                          |
| Package manager | Package manager available                    | No package manager in runtime variants                |
| User            | Runs as `nobody` user                        | Runs as `nonroot` user                                |
| Image size      | 107MB (30.3MB compressed)                    | 80.9MB (21.1MB compressed) - 25% smaller              |
| Attack surface  | 29 total files, includes bash/curl           | 15 total files - 48% fewer components                 |
| Debugging       | Traditional shell debugging                  | Use Docker Debug or kubectl debug for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Kubernetes-specific debugging with `kubectl debug`

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For Kubernetes environments, you can use kubectl debug:

```bash
kubectl debug -n kube-system pod/<pod-name> -it --image=busybox --target=metrics-exporter
```

Or use Docker Debug if you have access to the node:

```bash
docker debug <container-id>
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

The ClickHouse Metrics Exporter Docker Hardened Image is available as runtime variants only. There are no `dev` variants
for this image.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item                  | Migration note                                                                                                     |
| --------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Base image**        | Replace your base images in your Dockerfile with a Docker Hardened Image.                                          |
| **Nonroot user**      | Runtime images run as a nonroot user. Ensure that necessary files and directories are accessible to that user      |
| **Multi-stage build** | Utilize images with a dev tag for build stages and runtime images for runtime.                                     |
| **TLS certificates**  | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates. |
| **Ports**             | Non-dev hardened images run as a nonroot user by default. Configure your application to use ports above 1024.      |
| **Entry point**       | Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                           |

### Migration process

1. **Find hardened images for your app.** A hardened image may have several variants. Inspect the image tags and find
   the image variant that meets your needs.

1. **Update the base image in your Dockerfile.** Update the base image in your application's Dockerfile to the hardened
   image you found in the previous step.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.** To ensure that your final image is as
   minimal as possible, you should use a multi-stage build. Use dev images for build stages and runtime images for final
   runtime.

1. **Install additional packages** Docker Hardened Images selectively remove certain tools while maintaining operational
   capabilities. You may need to install additional packages in your Dockerfile.

## Troubleshoot migration

### General debugging

Docker Hardened Images provide robust debugging capabilities through **Docker Debug**, which attaches comprehensive
debugging tools to running containers while maintaining the security benefits of minimal runtime images.

**Docker Debug** provides a shell, common debugging tools, and lets you install additional tools in an ephemeral,
writable layer that only exists during the debugging session:

```bash
docker debug <container-name>
```

**Docker Debug advantages:**

- Full debugging environment with shells and tools
- Temporary, secure debugging layer that doesn't modify the runtime container
- Install additional debugging tools as needed during the session
- Perfect for troubleshooting DHI containers while preserving security

### Permissions

Runtime image variants run as the nonroot user. Ensure that necessary files and directories are accessible to that user.
You may need to copy files to different directories or change permissions so your application running as a nonroot user
can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure your
applications to listen on ports 8000, 8080, or other ports above 1024.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
