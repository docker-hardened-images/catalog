## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this image

This image contains the `kube-webhook-certgen` binary, which is a certificate lifecycle management tool specifically
designed for Kubernetes admission webhooks. It solves the chicken-and-egg problem of webhook deployment: webhooks need
TLS certificates to start, but certificate management tools might not be available during initial cluster setup or Helm
hooks.

## Get started

### Getting help

```bash
docker run --rm dhi.io/kube-webhook-certgen:<tag> --help
```

## Common Kube Webhook Certgen use cases

### Use within Kubernetes

Typically the Kube Webhook Certgen image is used within Helm charts as a pre-install or post-install hook. A different
way to test this image is to simply create a Kubernetes Pod (and the associated Service Account) and run the
`kube-webhook-certgen` binary to create a certificate and store it into a secret.

First create the k8s manifests. Make sure you replace `dhi.io/kube-webhook-certgen:<tag>` with the appropriate tag.

```bash
cat > test.yaml << EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-webhook-certgen-sa
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: kube-webhook-certgen-sa-role
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kube-webhook-certgen-sa-rolebinding
  namespace: default
subjects:
  - kind: ServiceAccount
    name: kube-webhook-certgen-sa
    namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kube-webhook-certgen-sa-role
---
apiVersion: v1
kind: Pod
metadata:
  name: kube-webhook-certgen
  namespace: default
  labels:
    app: kube-webhook-certgen
spec:
  serviceAccountName: kube-webhook-certgen-sa
  restartPolicy: Never
  containers:
    - name: kube-webhook-certgen
      image: dhi.io/kube-webhook-certgen:<tag>
      imagePullPolicy: IfNotPresent
      args:
        - create
        - --host=localhost
        - --namespace=default
        - --secret-name=test-secret
      env:
        - name: GODEBUG
          value: "fips140=on,tlsmlkem=1"
EOF
```

After applying the manifest above you should see how Kubernetes creates the pod, executes the command and you should
have a new certificate created into the `test-secret` Kubernetes secret.

```console
$ kubectl apply -f test.yaml

serviceaccount/kube-webhook-certgen-sa created
role.rbac.authorization.k8s.io/kube-webhook-certgen-sa-role created
rolebinding.rbac.authorization.k8s.io/kube-webhook-certgen-sa-rolebinding created
pod/kube-webhook-certgen created

$ kubectl get all

NAME                       READY   STATUS      RESTARTS   AGE
pod/kube-webhook-certgen   0/1     Completed   0          7s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   10d

$ kubectl get secret test-secret -o yaml | yq .data.ca | base64 -d
-----BEGIN CERTIFICATE-----
MIIBdTCCARygAwIBAgIRANEf/OaGkMTv9XowCCvjjBkwCgYIKoZIzj0EAwIwDzEN
MAsGA1UEChMEbmlsMTAgFw0yNjAyMDIxNTM3MDRaGA8yMTI2MDEwOTE1MzcwNFow
DzENMAsGA1UEChMEbmlsMTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABFAkBUT4
jdc6W5d53HvBemZJusotEM9C1YJhg3Z7+/FR+4M7XsHnVK0bQ5uxxuOZc/0WbdHC
0oFgXrdBks78h1CjVzBVMA4GA1UdDwEB/wQEAwICBDATBgNVHSUEDDAKBggrBgEF
BQcDATAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBR6SAUCrjUMJyIdEbGc9nno
45WclTAKBggqhkjOPQQDAgNHADBEAiACJVDb9D3d2M28JlJ3r/TGgOqhcDvmiCOy
46O/jg/JtgIgdPkbNsIaj/L7FQ1G69SyPHGeOZpHUsehs/smjb1Jx2g=
-----END CERTIFICATE-----
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Kube Webhook Certgen | Docker Hardened Kube Webhook Cergen            |
| --------------- | --------------------------------- | ---------------------------------------------- |
| Security        | Runs as root in scratch image     | Runs as nonroot user (UID 65532)               |
| Base image      | scratch                           | Minimal Debian with security patches           |
| User            | root (UID 0)                      | nonroot (UID 65532)                            |
| CA certificates | Not included                      | Includes standard TLS certificates             |
| SBOM            | Not provided                      | Complete SBOM with all dependencies            |
| Attack surface  | Minimal but runs as root          | Minimal with non-root execution                |
| CVE scanning    | Limited metadata                  | Full vulnerability scanning and VEX statements |

### Why run as non-root?

Docker Hardened Images prioritize security through defense in depth:

- Principle of least privilege: The tool doesn't need root privileges to function
- Container escape mitigation: Non-root users have fewer privileges if compromised
- Compliance ready: Meets security requirements that mandate non-root containers
- Pod Security Standards: Compatible with restricted pod security policies

### Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug dhi.io/kube-webhook-certgen:<tag>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/kube-webhook-certgen:<tag> /dbg/bin/sh
```

### Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
  validated under FIPS 140, a U.S. government standard for secure cryptographic operations. The certificate generation
  in FIPS mode uses FIPS-validated cryptographic algorithms.

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

## Troubleshooting

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
