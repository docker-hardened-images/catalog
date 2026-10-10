## Installing the chart

### Prerequisites

Before installing, provide:

- A Kubernetes version supported by the upstream GitLab 10.1 chart and Helm 3.8 or later.
- Authenticated access to `dhi.io` from every node, normally through an image pull Secret.
- PostgreSQL and Redis endpoints reachable from the target namespace.
- An external Gitaly server compatible with GitLab 19.1, including its authentication token.
- S3-compatible, Google Cloud, or Azure object storage for artifacts, LFS objects, uploads, and packages.
- An external ingress or Gateway and externally managed TLS certificates.
- All Kubernetes Secrets listed below. Automatic secret generation is intentionally disabled.

The default `*.example.invalid` endpoints are placeholders and will not connect to real services.

### Required Secrets

Create the required Secrets below before installation. A row explicitly marked optional may be omitted. Use a secret manager
or your normal GitOps workflow; do not put production credentials directly in a values file.

| Secret | Required key(s) | Purpose |
| --- | --- | --- |
| `gitlab-postgresql-password` | `password` | PostgreSQL authentication |
| `gitlab-redis-password` | `password` | Redis authentication |
| `gitlab-gitaly-token` | `token` | External Gitaly authentication |
| `gitlab-object-storage` | `connection` | GitLab object-storage connection YAML |
| `gitlab-rails-secret` | `secrets.yml` | Rails secret material |
| `gitlab-shell-secret` | `secret` | GitLab Shell shared secret |
| `gitlab-workhorse-secret` | `shared_secret` | Workhorse shared secret |
| `gitlab-initial-root-password` | `password` | Initial administrator password |
| `gitlab-gitlab-shell-host-keys` | OpenSSH private and public host-key pairs | SSH host identity |
| `gitlab-registry-secret` | `registry-auth.key` | Rails registry JWT signing key, still consumed when registry serving is disabled |
| `gitlab-registry-notification` | `secret` | Registry notification secret consumed by Rails |
| `gitlab-gitlab-runner-secret` | `runner-registration-token` | Optional compatibility token consumed by migration configuration when present; bundled Runner remains disabled |

Follow GitLab's [manual secret documentation](https://docs.gitlab.com/charts/installation/secrets/) for formats and
cryptographically secure generation. Secret names and keys may be changed through the corresponding upstream values.

### Configure external services

Create a values file that overrides endpoints and deployment-specific settings but leaves the DHI image values intact:

```yaml
global:
  hosts:
    domain: gitlab.example.com
  image:
    pullSecrets:
      - name: helm-pull-secret
  psql:
    host: postgresql.database.svc.example.com
    port: 5432
    username: gitlab
    database: gitlabhq_production
  redis:
    host: redis.cache.svc.example.com
    port: 6379
  gitaly:
    external:
      - name: default
        hostname: gitaly.storage.svc.example.com
        port: 8075
  appConfig:
    artifacts:
      bucket: gitlab-artifacts
    lfs:
      bucket: gitlab-lfs
    uploads:
      bucket: gitlab-uploads
    packages:
      bucket: gitlab-packages
```

The `gitlab-object-storage` Secret's `connection` key must contain the provider-specific YAML described in the
[upstream object-storage documentation](https://docs.gitlab.com/charts/advanced/external-object-storage/).

### Authenticate to Docker Hardened Images

Create an image pull Secret using your Docker credentials:

```console
kubectl create namespace gitlab
kubectl -n gitlab create secret docker-registry helm-pull-secret \
  --docker-server=dhi.io \
  --docker-username='<Docker username>' \
  --docker-password='<Docker access token>' \
  --docker-email='<Docker email>'
```

See the [DHI Kubernetes authentication guide](https://docs.docker.com/dhi/how-to/k8s/#authentication) for details.

### Install

```console
helm upgrade --install gitlab oci://dhi.io/gitlab-chart \
  --version 10.1.6 \
  --namespace gitlab \
  --create-namespace \
  --values gitlab-values.yaml \
  --timeout 20m
```

The chart does not create ingress resources by default. Configure your external ingress to route HTTP traffic to the
Workhorse service and TCP/SSH traffic to the GitLab Shell service, following the upstream GitLab networking guidance.

### Verify

```console
kubectl -n gitlab get pods,jobs,services
helm -n gitlab status gitlab
helm -n gitlab test gitlab
```

The migration Job must complete before Webservice and Sidekiq become ready. If dependency init containers remain pending,
verify the external PostgreSQL, Redis, and Gitaly endpoints and their Secrets.

## Hardened-configuration boundaries

Do not enable bundled components merely by changing an `enabled` or `install` value. Unsupported local subcharts retain
their upstream image defaults and are not part of the DHI image-closure guarantee. Deploy equivalent external services
separately with hardened images, or extend the chart only after compatible DHI images and runtime validation exist.

In particular, keep these values disabled: `global.gitaly.enabled`, `global.kas.enabled`, `global.pages.enabled`,
`registry.enabled`, `gitlab.toolbox.enabled`, `shared-secrets.enabled`, `installCertmanager`, `prometheus.install`,
`gitlab-runner.install`, `nginx-ingress.enabled`, `traefik.install`, `haproxy.install`, `gitlab-zoekt.install`,
`openbao.install`, `global.gatewayApi.installEnvoy`, and `ai-gateway.install`.

Custom CA injection is supported by the DHI Bash certificate initializer. Supply CA certificates through
`global.certificates.customCAs` using the upstream Secret or ConfigMap format.
