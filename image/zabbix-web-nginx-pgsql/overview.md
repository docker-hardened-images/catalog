## About Zabbix Web Nginx PostgreSQL

Zabbix is an open source monitoring solution for networks, servers, virtual machines, applications, and cloud services.
This image packages the Zabbix web interface, the PHP frontend served by nginx and PHP-FPM, for a Zabbix server that
stores its data in PostgreSQL. The frontend is where you configure hosts, templates, and alerts, and where you view
dashboards, graphs, and problems.

The image replaces `zabbix/zabbix-web-nginx-pgsql`: it runs the upstream entrypoint and reads the same environment
variables. It is available for the 6.0 LTS, 7.0 LTS, 7.4, and 8.0 LTS release lines. For more details, visit
https://www.zabbix.com/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Zabbix is a registered trademark of Zabbix LLC. All rights in the mark are reserved to Zabbix LLC. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
