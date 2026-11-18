## About GLPI

[GLPI](https://glpi-project.org) is an open-source IT service management and asset inventory web application, licensed
under GPL-3.0-or-later. The source is [glpi-project/glpi](https://github.com/glpi-project/glpi).

This image serves GLPI with nginx and PHP-FPM on port 80, runs GLPI's scheduled tasks in the same container, and stores
its state under `/var/glpi`. It needs a separate MySQL or MariaDB server.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

MySQL is a registered trademark of Oracle Corporation. MariaDB is a registered trademark of MariaDB plc. All rights in
those marks are reserved to their respective owners. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
