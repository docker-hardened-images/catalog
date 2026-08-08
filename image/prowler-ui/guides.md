## How to use this image

Authenticate with `docker login dhi.io` before pulling the image. Prowler UI requires a reachable Prowler API.

```bash
# Export AUTH_SECRET from a secrets manager or secure shell session first.
docker run --rm -p 3000:3000 \
  -e UI_API_BASE_URL=https://prowler-api.example.com/api/v1 \
  -e AUTH_URL=https://prowler.example.com \
  -e AUTH_SECRET \
  dhi.io/prowler-ui:<tag>
```

Set `AUTH_SECRET` in the parent environment from your deployment platform's secret store. Do not put the secret value in source control, the image, or command-line arguments.

### Runtime configuration

| Variable | Purpose |
| --- | --- |
| `UI_API_BASE_URL` | Required Prowler API v1 base URL. |
| `AUTH_URL` | Required public URL of this UI deployment. |
| `AUTH_SECRET` | Required random authentication secret; always inject securely. |
| `UI_API_DOCS_URL` | Optional API documentation URL. |
| `UI_CLOUD_ENABLED` | Set to `true` only for Prowler Cloud deployments. |
| `UI_SENTRY_ENABLED`, `UI_SENTRY_DSN`, `UI_SENTRY_ENVIRONMENT` | Optional Sentry integration. |
| `UI_GOOGLE_TAG_MANAGER_ENABLED`, `UI_GOOGLE_TAG_MANAGER_ID` | Optional Google Tag Manager integration. |
| `PORT` | Internal listen port; defaults to `3000`. |
| `HOSTNAME` | Listen address; defaults to `0.0.0.0`. |

The enabled integration flags are gates: when a gate is `true`, its corresponding configuration is required. Do not provide telemetry credentials unless the integration is intentionally enabled.

### Health probes

Probe `/api/health` on port 3000. The image does not include `curl`; use the orchestrator's HTTP probe support.

```yaml
livenessProbe:
  httpGet: { path: /api/health, port: 3000 }
readinessProbe:
  httpGet: { path: /api/health, port: 3000 }
```

## Migration notes

| Item | Upstream image | Docker Hardened Image |
| --- | --- | --- |
| Image | `prowlercloud/prowler-ui:5.36.0` | `dhi.io/prowler-ui:<tag>` |
| Runtime | Alpine-based Node image | Minimal Debian 13 Node.js 24 runtime |
| User | `nextjs` uid 1001 | `nonroot` uid/gid 65532 |
| Command | `node server.js` | `dumb-init -- node server.js` |
| Port | 3000 | 3000 |
| Build output | Next.js standalone | Next.js standalone |

The runtime has no shell or package manager. Use Docker Debug for troubleshooting. If mounting files beneath `/app`, ensure they are readable by uid 65532 and do not hide the standalone server files.

## Additional resources

- [Prowler documentation](https://docs.prowler.com/)
- [Prowler App deployment](https://docs.prowler.com/projects/prowler-open-source/en/latest/tutorials/prowler-app/)
- [Prowler source](https://github.com/prowler-cloud/prowler)
