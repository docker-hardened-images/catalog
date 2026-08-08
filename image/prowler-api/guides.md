## How to use this image

Authenticate with `docker login dhi.io` before pulling the public image. Replace `<tag>` with a published 5.36 tag. Prowler App requires separate API, worker, beat, UI, PostgreSQL, and Valkey or Redis services; Neo4j is additionally required for attack paths.

### Runtime roles

The default role starts the production API:

```bash
docker run --rm -p 8080:8080 \
  --env-file /secure/path/prowler-api.env \
  dhi.io/prowler-api:<tag>
```

Use the same image with a command override for workers and the scheduler:

```bash
# Celery worker
docker run --rm --env-file /secure/path/prowler-api.env \
  dhi.io/prowler-api:<tag> worker

# Celery Beat; run exactly one scheduler replica
docker run --rm --env-file /secure/path/prowler-api.env \
  dhi.io/prowler-api:<tag> beat
```

The image entrypoint accepts `prod`, `worker`, or `beat`. `prod` runs database migrations before starting Gunicorn. Coordinate deployments so only the intended API replicas perform migrations, and run a single `beat` replica to avoid duplicate scheduling.

### Required configuration

Use the upstream Prowler deployment documentation as the source of truth. Common settings include:

| Variable | Purpose |
| --- | --- |
| `DJANGO_TOKEN_SIGNING_KEY` / `DJANGO_TOKEN_VERIFYING_KEY` | Asymmetric keys used to sign and verify tokens. Supply as secrets. |
| `DJANGO_SECRETS_ENCRYPTION_KEY` | Encrypts provider credentials at rest. Supply as a secret. |
| `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | PostgreSQL connectivity. |
| `VALKEY_HOST`, `VALKEY_PORT`, `VALKEY_DB`, `VALKEY_PASSWORD` | Celery broker connectivity. |
| `DJANGO_ALLOWED_HOSTS` | Hostnames accepted by Django. Do not use `*` in production. |
| `DJANGO_PORT` | API listen port; defaults to `8080`. |
| `DJANGO_WORKERS` | Gunicorn worker count. |
| `DJANGO_TMP_OUTPUT_DIRECTORY` | Writable report staging directory; defaults to `/tmp/prowler_api_output`. |
| `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD` | Neo4j connectivity for attack paths. |

Do not put credentials in an image, compose file committed to source control, or command history. Use Docker secrets, Kubernetes Secrets, or an external secrets manager.

### Included assessment tools

`trivy`, `zizmor`, and `pwsh` are on `PATH`. Trivy stores its writable cache under `/home/nonroot/.cache/trivy`. Microsoft 365 assessment support includes the ExchangeOnlineManagement 3.10.1, MicrosoftTeams 7.9.0, and MSAL.PS 4.37.0.0 modules.

### Health probes

Use orchestrator HTTP probes rather than adding a shell-based Docker health check. Probe `/health/live` for liveness and `/health/ready` for readiness on port 8080 after migrations complete. Prowler's Helm chart is a useful reference for current probe timings.

## Migration notes

| Item | Upstream image | Docker Hardened Image |
| --- | --- | --- |
| Image | `prowlercloud/prowler-api:5.36.0` | `dhi.io/prowler-api:<tag>` |
| User | Upstream `prowler` uid 1000 | `nonroot` uid/gid 65532 |
| Entrypoint | `/home/prowler/docker-entrypoint.sh prod` | `tini -- /opt/prowler/docker-entrypoint.sh prod` |
| Working directory | `/home/prowler/backend` | `/opt/prowler/backend` |
| Package manager | Build-derived Debian image | No package manager in runtime |
| Writable data | `/tmp/prowler_api_output` | Same default, owned by uid 65532 |

If a persistent report or cache volume is mounted, ensure uid/gid 65532 can write it. The runtime has only the tools required by Prowler; use Docker Debug for troubleshooting rather than installing packages into a running container.

## Additional resources

- [Prowler documentation](https://docs.prowler.com/)
- [Prowler App deployment](https://docs.prowler.com/projects/prowler-open-source/en/latest/tutorials/prowler-app/)
- [Prowler source](https://github.com/prowler-cloud/prowler)
