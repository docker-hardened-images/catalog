## About WordPress

WordPress is a free and open-source content management system (CMS) written in PHP and paired with MySQL or MariaDB.
First released in 2003, WordPress has grown to power over 40% of all websites on the internet, making it the world's
most popular website builder and CMS.

WordPress provides a user-friendly interface for creating and managing website content, along with thousands of themes
and plugins that extend its functionality. It's used for everything from personal blogs to large corporate websites,
e-commerce stores, and web applications.

This Docker Hardened WordPress image includes:

- **WordPress Core**: Latest 6.9.x version bundled (can be replaced with your own version)
- **PHP-FPM**: FastCGI Process Manager for efficient PHP processing (PHP 8.3 or 8.4)
- **Required Extensions**: mysqli for database connectivity, json support (built-in to PHP)
- **Recommended Extensions**: All WordPress-recommended extensions pre-installed:
  - Image processing: gd, imagick
  - Functionality: curl, dom, exif, fileinfo, zip, intl, mbstring, openssl, bcmath
  - Performance: opcache for accelerated PHP performance
- **Security hardening**: Runs as nonroot user (uid/gid 65532) with proper file permissions
- **WordPress-optimized PHP configuration**: Tuned settings for upload sizes, memory limits, and execution times

The image supports two deployment patterns:

1. **Bundled WordPress**: Use the included WordPress version for quick starts and testing
1. **Custom WordPress**: Mount your own WordPress sources for production deployments with full version control

For more information about WordPress, visit https://wordpress.org/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

WordPress is a registered trademark of the WordPress Foundation. All rights in the mark are reserved to the WordPress
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
