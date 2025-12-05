## About mosquitto

Eclipse Mosquitto is an open-source MQTT message broker that implements MQTT 3.1, 3.1.1 and 5.0. This Docker Hardened
Image packages the Mosquitto broker and client utilities (mosquitto_pub, mosquitto_sub, mosquitto_passwd, etc.) with a
secure, minimal runtime and a default configuration mounted at /mosquitto/config/mosquitto.conf.

Mosquitto is commonly used to provide lightweight publish/subscribe messaging for IoT devices, telemetry pipelines, and
microservices. Typical use cases include local development, home automation, edge gateways, and production MQTT brokers
with mounted configuration, persistent data volumes, and TLS authentication.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Eclipse® Mosquitto™ is a trademark of the Eclipse Foundation. All rights in the mark are reserved to the Eclipse
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
