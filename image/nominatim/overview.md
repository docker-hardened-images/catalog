## About Nominatim

Nominatim is the open-source geocoder behind the search on openstreetmap.org. It searches OpenStreetMap data by name and
address (geocoding) and finds the address of a coordinate (reverse geocoding).

This image runs Nominatim with its own PostgreSQL and PostGIS database. On first start it imports the OpenStreetMap
extract you point it at, then serves the Nominatim search API on port 8080. See https://nominatim.org for the project
documentation.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

OpenStreetMap® is a registered trademark of the OpenStreetMap Foundation. All rights in the mark are reserved to the
OpenStreetMap Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
