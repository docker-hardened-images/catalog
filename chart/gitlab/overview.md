## About this Helm chart

This Docker Hardened Images chart is built from the official GitLab Helm chart 10.1.6 and provides a deliberately
restricted Community Edition deployment whose default-rendered containers use only digest-pinned Docker Hardened
Images.

The chart uses:

- `dhi/gitlab-webservice` for Puma, Sidekiq, dependency checks, and database migrations
- `dhi/gitlab-workhorse`
- `dhi/gitlab-shell`
- `dhi/gitlab-exporter`
- `dhi/bash` for configuration and certificate initialization

GitLab's matching CNG 19.1.6 dependency and migration helper scripts are included in the chart under their MIT license.
Small template adaptations connect the official chart's runtime contracts to the DHI entrypoints without introducing an
unhardened helper image.

### Restricted architecture

This is not the upstream chart's all-in-one deployment. It requires externally operated PostgreSQL, Redis, Gitaly,
object storage, ingress/TLS, and pre-created Kubernetes Secrets. Placeholder hosts under `example.invalid` intentionally
fail closed until they are replaced.

The following unsupported bundled components are disabled by default: internal Gitaly and Praefect, GitLab Agent Server
(KAS), container registry, GitLab Pages, GitLab Runner, Toolbox, Geo Log Cursor, Mailroom, Prometheus, cert-manager,
NGINX Ingress, Traefik, HAProxy, Envoy Gateway, Zoekt, OpenBao, AI Gateway, and automatic shared-secret generation.
External optional chart dependencies are removed while packaging. Enabling an unsupported local subchart can render
non-DHI images and is outside this chart's hardened configuration.

Workhorse direct object-storage access and Redis keywatcher are disabled because the minimal DHI Workhorse image does not
include the upstream gomplate configuration entrypoint. Object-storage traffic is proxied through Rails instead.

The chart follows GitLab chart 10.1.6 (GitLab 19.1.6); the available Webservice DHI is the compatible 19.1.7 patch release
and the Workhorse DHI is 19.1.6. Review the [guide](./guides.md) and the official GitLab chart documentation before use.

## About GitLab

GitLab is a DevSecOps platform for planning, source-code management, continuous integration, security, and software
delivery. Learn more at https://about.gitlab.com/ and https://docs.gitlab.com/charts/.

## About Docker Hardened Images

Docker Hardened Images provide minimal, security-focused images with signed provenance, SBOMs, and VEX metadata. They are
designed to reduce software supply-chain risk while fitting existing container workflows.

## Trademarks

GitLab is a trademark of GitLab Inc. Its use here is referential and does not indicate sponsorship, endorsement, or
affiliation. Docker and Docker Hardened Images are trademarks of Docker, Inc.
