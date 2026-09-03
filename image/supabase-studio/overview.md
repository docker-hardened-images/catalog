## About Supabase Studio

Supabase Studio is the web dashboard for a self-hosted [Supabase](https://github.com/supabase/supabase) stack. It gives
developers a table editor, SQL editor, authentication and user management, a storage browser, edge functions management,
log viewers, and other project administration tools for a Postgres-backed backend.

Studio ships as the `studio` service in Supabase's self-hosted Docker Compose stack, alongside services such as
`gotrue`, `postgrest`, `realtime`, `storage-api`, `postgres-meta`, `supavisor`, and `postgres`, typically fronted by an
API gateway. It's a Next.js application served in standalone mode and, on its own, renders the UI but requires those
backend services to be functional.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Supabase is a trademark of Supabase, Inc. All rights in the mark are reserved to Supabase, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
