## About Adminer

Adminer is a full-featured database management tool distributed as a single PHP file. It provides a lightweight
alternative to tools like phpMyAdmin, supporting MySQL, MariaDB, PostgreSQL, SQLite, MS SQL, and Oracle through a
plugin-extensible driver system.

Unlike many database tools, Adminer requires no configuration file or environment-based connection setup — you connect
to a database directly from its login form, specifying the driver, server, and credentials at login time. This makes it
well suited for ad hoc administration against any reachable database server.

This Docker Hardened Adminer image includes:

- **Adminer**: compiled from source at the latest release, including the `designs/` theme collection and the bundled
  community `plugins/`
- **PHP-FPM**: FastCGI Process Manager for efficient PHP processing (PHP 8.5)
- **Database drivers**: `mysqli` (MySQL/MariaDB), `pdo_pgsql` (PostgreSQL), `pdo_sqlite` (SQLite), `pdo_odbc` (generic
  ODBC), and `pdo_dblib` (MS SQL / Sybase via FreeTDS) — built from PHP source to match Adminer's full driver support
- **Design and plugin loading**: the `ADMINER_DESIGN` and `ADMINER_PLUGINS` environment variables select a UI theme and
  load community plugins at container start, matching the official image's behavior
- **Security hardening**: runs as nonroot user (uid/gid 65532); Adminer's own `Adminer\Password` feature additionally
  refuses to authenticate against a database with no password by default
- **Tuned PHP configuration**: upload limits, memory, and execution time raised so SQL dump import/export work at
  realistic file sizes

Adminer's PHP-FPM process listens on port 9000 and requires a web server (nginx, Apache, Caddy) in front of it to handle
HTTP requests.

For more information about Adminer, visit https://www.adminer.org/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Adminer is a project of Jakub Vrána. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation.
