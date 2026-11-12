## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/oathkeeper-maester:<tag>`
- Mirrored image: `<your-namespace>/dhi-oathkeeper-maester:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## About this image

Ory Oathkeeper Maester is a Kubernetes controller that watches `Rule` resources in the `oathkeeper.ory.sh/v1alpha1` API
group and renders every valid rule into the access rules document that Ory Oathkeeper consumes. It runs in two modes:

- `controller` (default): a standalone Deployment that writes the rules into a ConfigMap, which Oathkeeper mounts.
- `sidecar`: a container next to Oathkeeper that writes the rules to a file on a shared volume.

The image entrypoint is `/manager`, matching the upstream image. See the
[upstream project](https://github.com/ory/oathkeeper-maester) for the full flag reference.

## Run the container

Show the available flags. The controller exits after printing them:

```
docker run --rm dhi.io/oathkeeper-maester:<tag> --help
```

Maester needs a Kubernetes API server to do anything useful, so the remaining examples run it in a cluster.

### Environment variables

The following variables apply in both controller and sidecar mode.

| Variable                  | Description                                                                                                            | Default                                                                                                      |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `NAMESPACE`               | Restricts the manager to one namespace; in controller mode the rules ConfigMap must live there too. Empty watches all. | empty                                                                                                        |
| `authenticatorsAvailable` | Comma-separated authenticator handlers a rule may reference.                                                           | `noop,unauthorized,anonymous,cookie_session,oauth2_client_credentials,oauth2_introspection,jwt,bearer_token` |
| `authorizersAvailable`    | Comma-separated authorizer handlers a rule may reference.                                                              | `allow,deny,keto_engine_acp_ory,remote,remote_json`                                                          |
| `mutatorsAvailable`       | Comma-separated mutator handlers a rule may reference.                                                                 | `noop,id_token,header,cookie,hydrator`                                                                       |
| `errorsAvailable`         | Read at startup but not enforced in this version.                                                                      | `json,redirect,www_authenticate`                                                                             |

A rule whose authenticators, authorizer or mutators reference a handler outside these lists is marked
`status.validation.valid: false` and is left out of the rendered rules.

## Install the Rule CRD

Both modes require the `Rule` custom resource definition. Replace `<version>` with the Oathkeeper Maester version the
image ships:

```
kubectl apply -f https://raw.githubusercontent.com/ory/oathkeeper-maester/v<version>/config/crd/bases/oathkeeper.ory.sh_rules.yaml
```

## Run in controller mode

The controller needs a ServiceAccount that can read and update `Rule` objects and manage ConfigMaps. The ClusterRole
below mirrors upstream `config/rbac/role.yaml` at the release tag. Save the following as `maester.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: oathkeeper-maester
  namespace: oathkeeper
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: oathkeeper-maester
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
  - apiGroups: ["oathkeeper.ory.sh"]
    resources: ["rules"]
    verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
  - apiGroups: ["oathkeeper.ory.sh"]
    resources: ["rules/status"]
    verbs: ["get", "patch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oathkeeper-maester
subjects:
  - kind: ServiceAccount
    name: oathkeeper-maester
    namespace: oathkeeper
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: oathkeeper-maester
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oathkeeper-maester
  namespace: oathkeeper
spec:
  replicas: 1
  selector:
    matchLabels:
      control-plane: controller-manager
  template:
    metadata:
      labels:
        control-plane: controller-manager
    spec:
      serviceAccountName: oathkeeper-maester
      containers:
        - name: manager
          image: dhi.io/oathkeeper-maester:<tag>
          command:
            - /manager
          args:
            - --metrics-addr=0.0.0.0:8080
            - controller
            - --rulesConfigmapName=oathkeeper-rules
            - --rulesConfigmapNamespace=oathkeeper
          ports:
            - name: metrics
              containerPort: 8080
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
```

Apply it and create a rule:

```
kubectl create namespace oathkeeper
kubectl apply -f maester.yaml
cat <<'EOF' | kubectl apply -f -
apiVersion: oathkeeper.ory.sh/v1alpha1
kind: Rule
metadata:
  name: allow-anonymous
  namespace: oathkeeper
spec:
  upstream:
    url: http://httpbin.oathkeeper.svc:8080
  match:
    methods: ["GET"]
    url: <http|https>://api.example.com/anonymous/<.*>
  authenticators:
    - handler: anonymous
  authorizer:
    handler: allow
  mutators:
    - handler: noop
EOF
```

The controller validates the rule, records the result in `status.validation`, and writes the rendered rules into the
`access-rules.json` key of the `oathkeeper-rules` ConfigMap. Check the validation result and the rendered rules:

```
kubectl get rule allow-anonymous -n oathkeeper -o jsonpath='{.status.validation}'
kubectl get configmap oathkeeper-rules -n oathkeeper -o jsonpath='{.data.access-rules\.json}'
```

Oathkeeper reads the rules through `access_rules.repositories`, as shown in the `oathkeeper-config` ConfigMap of the
sidecar section; in controller mode mount the `oathkeeper-rules` ConfigMap at `/etc/rules` instead of the shared volume.

A rule can set `spec.configMapName` to send its rules to a different ConfigMap in the rule's own namespace instead of
the default one.

## Run in sidecar mode

In sidecar mode Maester writes the rules to a file on a volume it shares with the Oathkeeper container, so no ConfigMap
round-trip is needed. The sidecar still watches `Rule` objects through the API server, so it needs its own
ServiceAccount with the `rules` and `rules/status` permissions. The Oathkeeper configuration points
`access_rules.repositories` at the shared file. Save the following as `sidecar.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: oathkeeper-maester
  namespace: oathkeeper
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: oathkeeper-maester-sidecar
rules:
  - apiGroups: ["oathkeeper.ory.sh"]
    resources: ["rules"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: ["oathkeeper.ory.sh"]
    resources: ["rules/status"]
    verbs: ["get", "patch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oathkeeper-maester-sidecar
subjects:
  - kind: ServiceAccount
    name: oathkeeper-maester
    namespace: oathkeeper
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: oathkeeper-maester-sidecar
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: oathkeeper-config
  namespace: oathkeeper
data:
  oathkeeper.yaml: |
    serve:
      proxy:
        port: 4455
      api:
        port: 4456
    access_rules:
      repositories:
        - file:///etc/rules/access-rules.json
    authenticators:
      anonymous:
        enabled: true
        config:
          subject: guest
    authorizers:
      allow:
        enabled: true
    mutators:
      noop:
        enabled: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oathkeeper
  namespace: oathkeeper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oathkeeper
  template:
    metadata:
      labels:
        app: oathkeeper
    spec:
      serviceAccountName: oathkeeper-maester
      containers:
        - name: oathkeeper
          image: dhi.io/oathkeeper:<tag>
          args: ["serve", "--config", "/etc/config/oathkeeper.yaml"]
          ports:
            - name: proxy
              containerPort: 4455
            - name: api
              containerPort: 4456
          volumeMounts:
            - name: rules
              mountPath: /etc/rules
              readOnly: true
            - name: config
              mountPath: /etc/config
              readOnly: true
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
        - name: maester
          image: dhi.io/oathkeeper-maester:<tag>
          command:
            - /manager
          args:
            - --metrics-addr=0.0.0.0:8080
            - sidecar
            - --rulesFilePath=/etc/rules/access-rules.json
          ports:
            - name: metrics
              containerPort: 8080
          volumeMounts:
            - name: rules
              mountPath: /etc/rules
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
      volumes:
        - name: rules
          emptyDir: {}
        - name: config
          configMap:
            name: oathkeeper-config
```

Apply it after the CRD, then create a `Rule` in the `oathkeeper` namespace as in the controller example. Oathkeeper
lists the rules it loaded from the shared file on its API port:

```
kubectl create namespace oathkeeper
kubectl apply -f sidecar.yaml
kubectl port-forward -n oathkeeper deployment/oathkeeper 4456:4456 &
wget -qO- http://127.0.0.1:4456/rules
```

## Install with Helm

The upstream `oathkeeper-maester` chart from the [Ory Helm repository](https://k8s.ory.com/helm/) deploys the controller
mode end to end. Point it at this image:

```
helm repo add ory https://k8s.ory.com/helm/charts
helm install oathkeeper ory/oathkeeper-maester \
  --namespace oathkeeper --create-namespace \
  --set image.registry=dhi.io \
  --set image.repository=oathkeeper-maester \
  --set image.tag=<tag>
```

The chart runs the container as `/manager`, drops all capabilities, and uses a read-only root filesystem, all of which
this image supports without changes.

- Sidecar mode through the `oathkeeper` chart from the same repository is enabled with
  `global.ory.oathkeeper.maester.mode=sidecar`; its image values re-root every container in the pod, so follow the
  [upstream chart documentation](https://github.com/ory/k8s/tree/master/helm/charts/oathkeeper) when pointing the
  sidecar and Oathkeeper containers at DHI images.

## Non-hardened images vs. Docker Hardened Images

- The binary is installed at `/usr/bin/oathkeeper-maester`; `/manager` is a symlink to it, so the upstream entrypoint
  and the `command: [/manager]` used by the Ory Helm charts keep working.
- The upstream image is built on distroless and sets `SSL_CERT_FILE`. This image ships the standard CA bundle at the
  default location, so no extra environment is needed for TLS to the API server.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
