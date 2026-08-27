## About Grafana MCP Server

The Grafana MCP Server is a Model Context Protocol server that provides AI agents and LLMs with comprehensive access to
Grafana and its observability ecosystem. This server enables intelligent automation and interaction with Grafana
resources including dashboards, datasources, metrics, logs, traces, alerting, and incident management.

### Key Capabilities

**Dashboards**

- Search and retrieve dashboards
- Get dashboard summaries and properties via JSONPath
- Create, update, and patch dashboards
- Query panel information and datasource details

**Datasources**

- List and fetch datasource configurations
- Support for Prometheus and Loki datasources
- Query metrics and logs through integrated datasources

**Prometheus Integration**

- Query metrics (instant and range queries)
- Retrieve metric metadata (metric names, label values)
- Access metric cardinality and time series information

**Loki Integration**

- Query logs and log metrics
- Retrieve label metadata and log stream statistics
- Search and analyze log data

**Alerting**

- List and fetch alert rules and their statuses
- Manage contact points for both Grafana-managed and external Alertmanagers
- Monitor alert configurations and notifications

**Incident Management**

- Search, create, and update incidents
- Add activities and annotations to incidents
- Track incident lifecycle and resolution

**Grafana OnCall**

- Manage on-call schedules and shifts
- Query current on-call users
- List and manage teams and users
- Handle alert groups with filtering capabilities

**Sift Investigations**

- List and retrieve investigations
- Analyze error patterns in logs
- Identify slow requests in Tempo traces
- Get investigation analyses and insights

**Additional Features**

- Read-only mode support for safe access
- Configurable tool categories (search, datasource, alerting, etc.)
- Debug mode for detailed logging
- Multiple transport options (stdio, SSE, streamable-http)

### Requirements

- Grafana version 9.0 or later for full functionality
- Appropriate API credentials and permissions

For more details, see the [official documentation](https://github.com/grafana/mcp-grafana).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Grafana® is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc. dba
Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
