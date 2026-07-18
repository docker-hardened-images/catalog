## About NetBox

NetBox is the open-source **source of truth** for network infrastructure. It combines IP address management (IPAM) and
data center infrastructure management (DCIM) into a single Django web application — modeling devices, racks, cables,
VLANs, prefixes, IPs, circuits, virtualization, tenancy, and contacts. NetBox exposes REST and GraphQL APIs that let
network automation pipelines query and mutate the model programmatically, and ships a custom-script and webhook system
for in-tool automation. It is the canonical inventory and topology store for thousands of production network operators.

## About this image

This image packages the NetBox web tier, the Django application served by the
[Granian](https://github.com/emmett-framework/granian) ASGI/WSGI server, for production deployment. The same image runs
in two roles via the `cmd` override:

- **web** (default): `granian` serving the NetBox UI and API on port 8080.
- **worker**: `python manage.py rqworker` for the background task queue.

NetBox 4.6 deprecated the standalone `manage.py housekeeping` command upstream, so it is not exposed as a separate mode
here.

Customers provide the runtime data stores: PostgreSQL (canonical state) and two Redis instances (the primary with
append-only persistence for the RQ queue + a separate cache instance). See the guides for a complete compose example.

## Variants

This image ships four variants on debian-13:

- **runtime** — the default; runs as nonroot uid 65532 and contains only the NetBox venv + Django app + the Granian
  server + the minimal C libraries needed to run.
- **dev** — runtime plus `apt` and standard build utilities, runs as root, for installing NetBox plugins via the
  recommended multi-stage Dockerfile pattern (see guides).
- **fips** — runtime variant with OpenSSL configured to load the FIPS provider; Python's `ssl`/`hashlib` and the C libs
  (libxmlsec1, libxslt1.1, libpq5, libldap) all run through it. Carries `fips-compliant: true` + `stig-certified: true`
  attestations (OpenSCAP attestation generated automatically in CI).
- **fips-dev** — fips variant with the dev overlay applied (apt + bash + coreutils + findutils, runs as root).

### SAML + FIPS caveat

NetBox supports SAML 2.0 single sign-on via `python3-saml`, which uses `xmlsec` for XML signature verification. In the
FIPS variants, xmlsec runs under the FIPS OpenSSL provider — non-FIPS hash algorithms (MD5 and some legacy uses of
SHA-1) are disabled. Most modern identity providers default to SHA-256 signing and work transparently; customers whose
IdP still signs with SHA-1 will see verification failures and need to update the IdP before adopting the FIPS variant.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

All third-party product names, logos, and trademarks are the property of their respective owners and are used solely for
identification. Docker claims no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
