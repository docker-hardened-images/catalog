## About GitLab Toolbox

GitLab Toolbox is the maintenance and disaster-recovery container for a Cloud Native GitLab (CNG) deployment. It
includes the GitLab Rails application together with the `backup-utility`, `gitlab-rake`, `gitlab-rails`, and
`gitlab-backup-cli` wrappers, so operators can create and restore backups, run migrations, open a Rails console, and run
maintenance tasks against a running GitLab installation.

This image ships the GitLab Community Edition source tree. It is a client of an existing GitLab deployment rather than a
service of its own. It opens no ports, and it needs a mounted GitLab configuration and network access to that
deployment's PostgreSQL, Redis, and Gitaly services before it can do anything.

For more information, visit the [official GitLab documentation](https://docs.gitlab.com/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

GitLab is a trademark of GitLab Inc. in the United States and other countries and regions. All rights in the mark are
reserved to GitLab Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.

Amazon Web Services and AWS are trademarks of Amazon.com, Inc. or its affiliates. Google Cloud and Google Cloud Storage
are trademarks of Google LLC. PostgreSQL is a trademark of the PostgreSQL Community Association of Canada. Redis is a
registered trademark of Redis Ltd. All rights in these marks are reserved to their respective owners. Any use by Docker
is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
