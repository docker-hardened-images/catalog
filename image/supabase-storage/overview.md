## About Supabase Storage

Supabase Storage is an object storage service. It stores object data in any S3-compatible backend or on a mounted
filesystem, and keeps the metadata for buckets and objects in PostgreSQL. Because that metadata is in Postgres, you can
control access to buckets and objects with the same Row Level Security policies you use for the rest of your schema.

It serves a REST API, an S3-compatible endpoint, resumable uploads over the TUS protocol, an Iceberg REST catalog, and
image transformation on request. Releases and full documentation are on [GitHub](https://github.com/supabase/storage).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Supabase is a trademark of Supabase, Inc. PostgreSQL and the PostgreSQL elephant logo are trademarks or registered
trademarks of the PostgreSQL Community Association of Canada. Amazon S3 is a trademark of Amazon.com, Inc. or its
affiliates. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
