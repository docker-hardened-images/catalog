## About Drupal Nginx

Drupal Nginx is the Nginx web server packaged with the wodby/nginx configuration set: an entrypoint that renders
`/etc/nginx` from `NGINX_*` environment variables, and a library of virtual host presets. The presets cover Drupal 7
through Drupal 11 along with WordPress, Laravel, Django, Matomo, plain PHP, static HTML, and HTTP proxying, so a
front-end web server can be pointed at a PHP-FPM or application backend without hand-writing an Nginx configuration.

The image is intended as the web server tier in front of a PHP-FPM container: select a preset with `NGINX_VHOST_PRESET`,
point `NGINX_BACKEND_HOST` at the application container, and mount the document root. It builds on the same hardened
Nginx packages as the Docker Hardened Nginx image, with the Brotli, upload progress, and virtual host traffic status
modules the presets require.

For more details, visit https://github.com/wodby/nginx.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
