## About Prowler API

Prowler is an open-source cloud security platform that assesses AWS, Azure, Google Cloud, Kubernetes, Microsoft 365, and other environments against security and compliance best practices. The Prowler API is the Django and Django REST Framework backend used by Prowler App. It persists providers, scans, findings, resources, schedules, and compliance results in PostgreSQL and dispatches scan work through Celery.

## About this image

This image packages the Prowler 5.36.0 API and its Celery processes. One immutable image supports all production roles by overriding its command:

- **API** (default): `prod` applies migrations and starts Gunicorn with ASGI workers on port 8080.
- **Worker**: `worker` processes scans, reports, integrations, compliance, and attack-path jobs.
- **Scheduler**: `beat` runs Celery Beat with the Django database scheduler.

The runtime includes the functionality expected by upstream Prowler: PowerShell 7.5.0 with pinned Exchange Online, Microsoft Teams, and MSAL modules; Trivy 0.71.2 for image and IaC analysis; and zizmor 1.24.1 for GitHub Actions workflow analysis. It runs as nonroot uid 65532 and contains no package manager or build toolchain.

PostgreSQL, Valkey or Redis, and (when attack-path functionality is enabled) Neo4j are external services and are not bundled in the image. Runtime signing keys, encryption keys, database credentials, cloud credentials, and API tokens must be supplied through a secrets manager or orchestrator.

## About Docker Hardened Images

Docker Hardened Images are built to meet high security and compliance standards. They provide a minimal, continuously maintained foundation, signed provenance, and a complete Software Bill of Materials (SBOM) and VEX metadata.

## Trademarks

Prowler is a trademark of Prowler, Inc. All third-party product names, logos, and trademarks are the property of their respective owners and are used solely for identification. Docker claims no affiliation, sponsorship, or endorsement.
