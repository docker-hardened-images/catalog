# Temporal Admin Tools Overview

The Temporal Admin Tools image provides a comprehensive set of command-line utilities for managing and administering
Temporal clusters. This image is designed to be used as a sidecar container or interactive toolbox for Temporal
operations.

## Key Features

- **Complete toolkit**: All essential Temporal administrative tools in one image
- **Database management**: Tools for both Cassandra and SQL database backends
- **Modern and legacy**: Includes both the new `temporal` CLI and legacy `tctl`
- **Debugging capabilities**: Built-in debugging tools for troubleshooting
- **Security hardened**: Runs as non-root user with minimal attack surface

## Architecture

The admin tools image is built using shared components with the Temporal server image, ensuring consistency and reducing
duplication. It includes:

- Administrative CLIs (`tctl`, `temporal`)
- Database schema management tools
- Debugging utilities
- Authorization plugins
- Configuration templates

## Use Cases

### Development

- Local development cluster management
- Schema initialization and migrations
- Workflow debugging and inspection

### Operations

- Production cluster administration
- Monitoring and health checks
- Backup and recovery operations
- Namespace management

### CI/CD

- Automated testing workflows
- Deployment validation
- Schema version management

## Integration

The admin tools image is designed to work alongside:

- **temporalio-server**: Core Temporal services
- **temporalio-ui**: Web interface
- Database backends (Cassandra, MySQL, PostgreSQL)
- Service discovery and load balancing

## Trademarks

Temporal™ is a trademark of Temporal Technologies, Inc. All rights in the mark are reserved to Temporal Technologies,
Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
