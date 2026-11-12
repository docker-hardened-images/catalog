## About phpMyAdmin

phpMyAdmin is a free software tool written in PHP, intended to handle the administration of MySQL and MariaDB over the
web. It supports a wide range of operations on databases, tables, columns, relations, indexes, users, and permissions
through the browser, while still giving you the ability to directly execute any SQL statement. Frequently used
operations are available from the user interface, including browsing and dropping databases, importing and exporting
data, and managing users and privileges.

This image ships phpMyAdmin as a PHP-FPM application on port `9000/tcp`, built from the GPG-verified upstream release
and served through a separate web server such as nginx. The PHP runtime comes from the Docker Hardened PHP packages,
with the extensions phpMyAdmin uses (`mysqli`, `gd`, `zip`, `bz2`, `bcmath`, and `uploadprogress`) compiled from the
matching PHP source and `opcache` enabled from the PHP package.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

phpMyAdmin is a registered trademark of Software Freedom Conservancy, Inc. MySQL is a registered trademark of Oracle
Corporation. MariaDB is a registered trademark of MariaDB plc. All rights in those marks are reserved to their
respective owners. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
