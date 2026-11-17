## About NGINX LDAP Auth

nginx-ldap-auth is a reference implementation of an LDAP authentication daemon for the NGINX `auth_request` module,
published by Nginx Inc. NGINX proxies an internal subrequest to the daemon, which validates the client's HTTP Basic
credentials (or an authentication cookie) against an LDAP directory -- OpenLDAP or Microsoft Active Directory -- and
answers with 200 (allow) or 401 (deny) so NGINX can gate access to a protected backend.

> **Warning:** The upstream project states that it is "not designed or hardened for production" and is intended as a
> model for building such connector daemons. Evaluate that caveat against your requirements before using this image as a
> production authentication gateway, and follow the hardened NGINX configuration in the usage guide -- in particular the
> `internal` and `proxy_pass_request_headers off` directives, TLS to the LDAP server, and keeping port 8888 unreachable
> from clients.

For more details, visit https://github.com/nginxinc/nginx-ldap-auth.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

NGINX® is a trademark of F5, Inc. All rights in the mark are reserved to F5, Inc. Any use by Docker is for referential
purposes only and does not indicate sponsorship, endorsement, or affiliation.
