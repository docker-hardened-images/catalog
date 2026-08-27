## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Basic Nginx monitoring with stub_status

The following command starts the NGINX Prometheus Exporter to monitor an Nginx server with stub_status enabled. Replace
`<tag>` with the image variant you want to run.

```
$ docker run --rm -p 9113:9113 dhi.io/nginx-exporter:<tag> --nginx.scrape-uri=http://nginx-server:80/nginx_status
```

### Monitor Nginx Plus with API

For Nginx Plus monitoring using the API endpoint:

```
$ docker run --rm -p 9113:9113 dhi.io/nginx-exporter:<tag> --nginx.scrape-uri=http://nginx-plus:8080/api --nginx.plus
```

### Configuration options

#### Basic configuration parameters

Set scrape URI:

```
$ docker run --rm dhi.io/nginx-exporter:<tag> --nginx.scrape-uri=http://nginx:80/nginx_status
```

Enable Nginx Plus mode:

```
$ docker run --rm dhi.io/nginx-exporter:<tag> --nginx.plus --nginx.scrape-uri=http://nginx-plus:8080/api
```

Configure listen address and port:

```
$ docker run --rm -p 8080:8080 dhi.io/nginx-exporter:<tag> --web.listen-address=:8080
```

#### SSL/TLS configuration

Monitor Nginx Plus with SSL:

```
$ docker run --rm -v $(pwd)/certs:/certs dhi.io/nginx-exporter:<tag> \
  --nginx.scrape-uri=https://nginx-plus:8443/api \
  --nginx.plus \
  --nginx.ssl-ca-cert=/certs/ca.crt \
  --nginx.ssl-client-cert=/certs/client.crt \
  --nginx.ssl-client-key=/certs/client.key
```

Skip SSL verification (not recommended for production):

```
$ docker run --rm dhi.io/nginx-exporter:<tag> \
  --nginx.scrape-uri=https://nginx-plus:8443/api \
  --nginx.plus \
  --nginx.ssl-skip-verify
```

#### Advanced configuration

Set custom scrape timeout:

```
$ docker run --rm dhi.io/nginx-exporter:<tag> --nginx.timeout=10s
```

Configure retry attempts:

```
$ docker run --rm dhi.io/nginx-exporter:<tag> --nginx.retries=3
```

Set custom user agent:

```
$ docker run --rm dhi.io/nginx-exporter:<tag> --nginx.user-agent="Custom-Monitor/1.0"
```

Enable debug logging:

```
$ docker run --rm dhi.io/nginx-exporter:<tag> --log.level=debug
```

### Docker Compose setup

#### Basic Nginx + Exporter

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro

  nginx-exporter:
    image: dhi.io/nginx-exporter:<tag>
    ports:
      - "9113:9113"
    command: ["-nginx.scrape-uri=http://nginx:80/nginx_status"]
    depends_on:
      - nginx

  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    depends_on:
      - nginx-exporter
```

Required Nginx configuration (`nginx.conf`):

```nginx
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;

        location /nginx_status {
            stub_status on;
            access_log off;
            allow all;  # Configure appropriate access controls
        }
    }
}
```

#### Nginx Plus setup

```yaml
services:
  nginx-plus:
    image: nginx-plus  # Requires NGINX Plus license
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - ./nginx-plus.conf:/etc/nginx/nginx.conf:ro

  nginx-exporter:
    image: dhi.io/nginx-exporter:<tag>
    ports:
      - "9113:9113"
    command:
      - "-nginx.scrape-uri=http://nginx-plus:8080/api"
      - "-nginx.plus"
    depends_on:
      - nginx-plus
```

### Kubernetes deployment

#### Basic deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-exporter
  labels:
    app: nginx-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-exporter
  template:
    metadata:
      labels:
        app: nginx-exporter
    spec:
      containers:
      - name: nginx-exporter
        image: dhi.io/nginx-exporter:<tag>
        args:
          - "-nginx.scrape-uri=http://nginx-service:80/nginx_status"
        ports:
        - containerPort: 9113
          name: metrics
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
        livenessProbe:
          httpGet:
            path: /
            port: metrics
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: metrics
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-exporter-service
  labels:
    app: nginx-exporter
spec:
  selector:
    app: nginx-exporter
  ports:
  - port: 9113
    targetPort: metrics
    name: metrics
```

#### ServiceMonitor for Prometheus Operator

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx-exporter
  labels:
    app: nginx-exporter
spec:
  selector:
    matchLabels:
      app: nginx-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

#### Nginx Ingress Controller monitoring

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-ingress-exporter
spec:
  selector:
    matchLabels:
      app: nginx-ingress-exporter
  template:
    metadata:
      labels:
        app: nginx-ingress-exporter
    spec:
      containers:
      - name: nginx-exporter
        image: dhi.io/nginx-exporter:<tag>
        args:
          - "--nginx.scrape-uri=http://127.0.0.1:10254/nginx_status"
        ports:
        - containerPort: 9113
          hostPort: 9113
          name: metrics
        resources:
          limits:
            cpu: 50m
            memory: 64Mi
      hostNetwork: true
      tolerations:
      - operator: Exists
```

### Prometheus configuration

Add the following job to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'nginx-exporter'
    static_configs:
      - targets: ['nginx-exporter:9113']
    scrape_interval: 30s
    metrics_path: /metrics

  # For Kubernetes service discovery
  - job_name: 'nginx-exporter-k8s'
    kubernetes_sd_configs:
      - role: endpoints
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: nginx-exporter-service
      - source_labels: [__meta_kubernetes_endpoint_port_name]
        action: keep
        regex: metrics
```

### Grafana dashboards

#### Key metrics to monitor

Import or create dashboards with these essential metrics:

**Connection metrics:**

- `nginx_connections_active` - Active connections
- `nginx_connections_accepted` - Accepted connections rate
- `nginx_connections_handled` - Handled connections rate

**Request metrics:**

- `nginx_http_requests_total` - Total HTTP requests
- `rate(nginx_http_requests_total[5m])` - Request rate

**NGINX Plus specific:**

- `nginxplus_upstream_server_responses_total` - Upstream responses
- `nginxplus_upstream_server_response_time` - Response times
- `nginxplus_cache_hit_ratio` - Cache hit ratio

#### Sample Grafana queries

Request rate:

```promql
rate(nginx_http_requests_total[5m])
```

Connection utilization:

```promql
nginx_connections_active / nginx_connections_accepted
```

Upstream health (NGINX Plus):

```promql
nginxplus_upstream_server_up == 0
```

### Monitoring best practices

#### Health checks and alerting

Create alerts for key metrics:

```yaml
# prometheus-alerts.yml
groups:
- name: nginx-alerts
  rules:
  - alert: NginxDown
    expr: up{job="nginx-exporter"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "NGINX Exporter is down"

  - alert: NginxHighRequestRate
    expr: rate(nginx_http_requests_total[5m]) > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High request rate detected"

  - alert: NginxHighConnectionUsage
    expr: nginx_connections_active > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High connection usage"
```

#### Performance optimization

Optimize scrape intervals based on your needs:

```yaml
scrape_configs:
  - job_name: 'nginx-exporter'
    scrape_interval: 15s  # High-frequency monitoring
    # OR
    scrape_interval: 60s  # Lower overhead monitoring
```

Configure appropriate resource limits:

```yaml
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

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

For NGINX Exporter specifically, ensure that:

- Volume mounts (SSL certificates) are readable by the nonroot user (UID 65532)
- Network access to NGINX endpoints is properly configured
- Port bindings are correct for the container environment

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The NGINX
Exporter defaults to port 9113, which is fine, but if you need to change it, ensure you use port 1025 or higher.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

### NGINX Exporter specific troubleshooting

#### Connection issues

If the exporter can't connect to NGINX:

```bash
# Test connectivity to NGINX status endpoint
curl http://nginx-server:80/nginx_status

# Check if stub_status is properly configured
# Should return something like:
# Active connections: 2
# server accepts handled requests
#  16630 16630 31070
# Reading: 0 Writing: 1 Waiting: 1
```

#### SSL certificate issues

For NGINX Plus with SSL:

```bash
# Verify certificates are readable
docker run --rm -v $(pwd)/certs:/certs dhi.io/nginx-exporter:<tag> ls -la /certs

# Test SSL connection manually
openssl s_client -connect nginx-plus:8443 -cert client.crt -key client.key -CAfile ca.crt
```

#### Metrics not appearing

Common issues and solutions:

1. **Wrong scrape URI**: Ensure the URI matches your NGINX configuration
1. **NGINX Plus flag**: Use `-nginx.plus` flag when monitoring NGINX Plus
1. **Network connectivity**: Verify network access between exporter and NGINX
1. **Permissions**: Check that the status/API endpoint allows connections from the exporter
