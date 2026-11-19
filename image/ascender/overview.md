## About Ascender

Ascender is the automation controller from CIQ, built on the AWX project. It provides the web user interface, the REST
API and the task services that schedule and run Ansible automation, backed by PostgreSQL and a Valkey cache, with
playbooks executed in a separate execution environment image.

This image contains the Ascender control plane: the Django application in a Python 3.12 virtual environment, the built
web UI, nginx, uwsgi, daphne, supervisord and rsyslogd, together with the launch scripts the
[ascender-operator](https://github.com/ctrliq/ascender-operator) starts each role with. The same image runs the web,
task and rsyslog roles and the migration job; the operator selects the role through the container arguments. The image
runs as the nonroot uid 1000, as upstream; the shell utilities it ships (`bash`, `sh`, `sed`, `grep`, `awk` and
coreutils) are the ones the launch scripts, `wait-for-migrations` and the operator's probes run.

For more details, see the [upstream project](https://github.com/ctrliq/ascender).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

The AWX Project is a trademark of Red Hat, Inc.
([AWX Trademark Guidelines](https://github.com/ansible/awx-logos/blob/master/TRADEMARKS.md)). Kubernetes is a registered
trademark of The Linux Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
