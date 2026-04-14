## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this NiFi image

This Docker Hardened NiFi image includes :

- `nifi`: The Apache NiFi application, built from source for secure data flow automation and processing.
- `nifi-toolkit`: Administrative utilities for NiFi management and configuration.
- Java Runtime Environment: OpenJDK 21 JRE, required runtime for NiFi operation. Java runtime located at
  `/opt/java/openjdk/21-jre`.
- Python 3: Runtime support for Python-based NiFi processors.

### Start a NiFi image

Run a standalone instance with HTTPS and single-user authentication:

```
docker run -d \
  --name nifi \
  -p 8443:8443 \
  dhi.io/nifi:<tag>
```

The NiFi UI is available at [https://localhost:8443/nifi](https://localhost:8443/nifi). On startup, NiFi generates
random single-user credentials and writes them to the application log. Retrieve them with:

```
docker logs nifi | grep Generated
```

### Configure HTTPS port

```
docker run -d --name nifi \
  -p 9443:9443 \
  -e NIFI_WEB_HTTPS_PORT=9443 \
  dhi.io/nifi:<tag>
```

### Configure single-user credentials

```
docker run -d --name nifi \
  -p 8443:8443 \
  -e SINGLE_USER_CREDENTIALS_USERNAME=admin \
  -e SINGLE_USER_CREDENTIALS_PASSWORD=StrongPassword123 \
  dhi.io/nifi:<tag>
```

Passwords must be at least 12 characters. If not provided, NiFi generates random credentials at startup.

### Secure NiFi with TLS

#### Mutual TLS authentication

Provide certificates via a volume mount and set authentication to TLS:

```
docker run -d --name nifi \
  -v /path/to/certs:/opt/certs \
  -p 8443:8443 \
  -e AUTH=tls \
  -e KEYSTORE_PATH=/opt/certs/keystore.jks \
  -e KEYSTORE_TYPE=JKS \
  -e KEYSTORE_PASSWORD=changeit \
  -e TRUSTSTORE_PATH=/opt/certs/truststore.jks \
  -e TRUSTSTORE_TYPE=JKS \
  -e TRUSTSTORE_PASSWORD=changeit \
  -e INITIAL_ADMIN_IDENTITY="CN=Admin, O=Org, C=US" \
  dhi.io/nifi:<tag>
```

#### LDAP authentication

For LDAP-backed authentication:

```
docker run -d --name nifi \
  -v /path/to/certs:/opt/certs \
  -p 8443:8443 \
  -e AUTH=ldap \
  -e KEYSTORE_PATH=/opt/certs/keystore.jks \
  -e KEYSTORE_PASSWORD=changeit \
  -e TRUSTSTORE_PATH=/opt/certs/truststore.jks \
  -e TRUSTSTORE_PASSWORD=changeit \
  -e INITIAL_ADMIN_IDENTITY="cn=admin,dc=example,dc=org" \
  -e LDAP_AUTHENTICATION_STRATEGY=SIMPLE \
  -e LDAP_MANAGER_DN="cn=admin,dc=example,dc=org" \
  -e LDAP_MANAGER_PASSWORD=password \
  -e LDAP_USER_SEARCH_BASE="dc=example,dc=org" \
  -e LDAP_USER_SEARCH_FILTER="cn={0}" \
  -e LDAP_URL="ldap://ldap:389" \
  dhi.io/nifi:<tag>
```

Optional variables for secure LDAP (LDAPS or START_TLS) are supported: `LDAP_TLS_KEYSTORE`,
`LDAP_TLS_KEYSTORE_PASSWORD`, `LDAP_TLS_TRUSTSTORE`, and related fields.

### Clustering

Enable clustering with the following environment variables:

| Property                                  | Env Var                                |
| ----------------------------------------- | -------------------------------------- |
| nifi.cluster.is.node                      | NIFI_CLUSTER_IS_NODE                   |
| nifi.cluster.node.address                 | NIFI_CLUSTER_ADDRESS                   |
| nifi.cluster.node.protocol.port           | NIFI_CLUSTER_NODE_PROTOCOL_PORT        |
| nifi.cluster.node.protocol.max.threads    | NIFI_CLUSTER_NODE_PROTOCOL_MAX_THREADS |
| nifi.zookeeper.connect.string             | NIFI_ZK_CONNECT_STRING                 |
| nifi.zookeeper.root.node                  | NIFI_ZK_ROOT_NODE                      |
| nifi.cluster.flow.election.max.wait.time  | NIFI_ELECTION_MAX_WAIT                 |
| nifi.cluster.flow.election.max.candidates | NIFI_ELECTION_MAX_CANDIDATES           |

## Configuration options

Default ports:

| Function            | Property                      | Port  |
| ------------------- | ----------------------------- | ----- |
| HTTPS UI            | nifi.web.https.port           | 8443  |
| JVM Debugger        | java.arg.debug                | 8000  |
| Remote Input Socket | nifi.remote.input.socket.port | 10000 |

Environment variables for configuring NiFi:

- `NIFI_VARIABLE_REGISTRY_PROPERTIES` – configure variable registry
- `NIFI_JVM_HEAP_INIT` / `NIFI_JVM_HEAP_MAX` – set JVM heap sizes
- `NIFI_JVM_DEBUGGER` – enable JVM debugging
- `NIFI_WEB_PROXY_CONTEXT_PATH` – set proxy context path
- `NIFI_WEB_PROXY_HOST` – set proxy host

## Non-hardened vs Docker Hardened Images

### Key differences

| Feature          | Upstream NiFi          | DHI NiFi                   |
| ---------------- | ---------------------- | -------------------------- |
| Java             | Full JDK               | JRE only (OpenJDK 21)      |
| User             | Runs as root           | Runs as nonroot (UID 1000) |
| Package manager  | Available              | Not included               |
| File system      | Default upstream paths | `/opt/nifi/nifi-current`   |
| Security posture | Larger attack surface  | Reduced CVE exposure       |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/<image-name>:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

## Migration steps

1. Update image reference. Replace the image reference in your Docker run command or Compose file:
   - From: `apache/nifi:<tag>`
   - To: `dhi.io/nifi:<tag>`
1. Fix permissions on mounted volumes:
   ```
   chown -R 1000:1000 /host/path
   ```
1. Verify processors are JRE-compatible.
1. Update configs to use `/opt/nifi/nifi-current`.
1. Ensure ports `8443`, `8000`, `10000` are available.

### General migration considerations

While the NiFi-specific configuration requires no changes, be aware of these general differences in Docker Hardened
Images:

| Item            | Migration note                                                         |
| --------------- | ---------------------------------------------------------------------- |
| Shell access    | No shell in runtime variants, use Docker Debug for troubleshooting     |
| Package manager | No package manager in runtime variants                                 |
| Debugging       | Use Docker Debug or Image Mount instead of traditional shell debugging |

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell or package manager. Use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session. Alternatively, use dev image variants during build stages and copy artifacts into
the runtime image.

### Common issues

- Permission denied

  Runtime images run as the nonroot user (UID 1000). Ensure mounted volumes and files are owned by UID 1000:

  ```
  chown -R 1000:1000 /host/path
  ```

  You may also need to adjust permissions so the NiFi process can access required directories.

- Processor compatibility

  Custom processors requiring JDK compilation tools will not work inside the runtime image. Build them externally and
  ensure they are JRE-compatible.

- Port binding conflicts

  By default NiFi uses ports 8443 (HTTPS), 8000 (JVM Debug), and 10000 (remote input). Verify these ports are free on
  the host. Nonroot containers cannot bind to privileged ports (\<1024) in Kubernetes or Docker versions older than
  20.10.

- Path resolution issues

  Update configurations and custom processors to use the hardened image path `/opt/nifi/nifi-current` instead of
  upstream defaults.
