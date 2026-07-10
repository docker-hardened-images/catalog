## About git-sync

git-sync is a sidecar application that pulls a git repository into a local directory and keeps it synchronized with a
remote. It is a Kubernetes project, most commonly run as a sidecar container to deliver configuration, code, or data
from a git repository into a shared volume that the main application consumes.

git-sync supports syncing one time or periodically, over HTTP(S) or SSH, with authentication via a token, an SSH key, a
cookie file, or a GitHub App. It performs atomic updates using a symlink, so consumers never observe a partial checkout,
and it can run webhooks or exec hooks after each successful sync.

For more details, see https://github.com/kubernetes/git-sync.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
