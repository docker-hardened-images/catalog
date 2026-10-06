## About Nextcloud

Nextcloud is a self-hosted content collaboration platform. It provides file sync and share, and through its app
ecosystem adds calendars, contacts, groupware, and real-time collaboration, all running on infrastructure you control.
Full project documentation is available at https://docs.nextcloud.com.

This image ships the Nextcloud server application together with the PHP runtime and the PHP extensions Nextcloud
requires. It runs **PHP-FPM** and expects an upstream web server, such as nginx, to serve static files and forward PHP
requests over FastCGI on port `9000`. Usage, configuration, and migration guidance live in the image guide.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Nextcloud and the Nextcloud logo are registered trademarks of Nextcloud GmbH in Germany and/or other countries. Use of
Nextcloud logos and other marks is only permitted under the guidelines provided by Nextcloud GmbH, available at
https://nextcloud.com/trademarks/.
