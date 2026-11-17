## About InfluxDB

InfluxDB is a high-performance time series database designed for storing and querying large volumes of time-stamped
data. It excels at handling metrics, events, and real-time analytics workloads with its purpose-built storage engine and
powerful query language. InfluxDB is commonly used for monitoring, IoT data collection, application metrics, financial
data analysis, and real-time analytics.

Key features of InfluxDB include:

- **Time Series Optimized**: Purpose-built for time series data with efficient compression and fast query performance
- **Flexible Data Model**: Tag-based data model that allows for high cardinality and flexible querying
- **Flux Query Language**: Powerful query language for data transformation and analysis
- **HTTP API**: RESTful API for easy integration with applications and tools
- **Built-in UI**: Web-based interface for data exploration and visualization
- **Retention Policies**: Automatic data retention and downsampling capabilities
- **High Write Throughput**: Handles millions of data points per second

InfluxDB is widely used in observability stacks, often paired with collection agents like Telegraf and visualization
tools like Grafana to create complete monitoring solutions.

For more details, visit https://docs.influxdata.com/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

InfluxDB® is a trademark of InfluxData. All rights in the mark are reserved to the Linux Foundation. Any use by Docker
is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
