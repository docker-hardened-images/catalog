## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/crossplane-provider-aws-sns:<tag>`
- Mirrored image: `<your-namespace>/dhi-crossplane-provider-aws-sns:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Crossplane Provider AWS SNS image

This image is the SNS service provider for the Crossplane provider for AWS. It manages SNS resources as Crossplane
managed resources. Cluster-scoped resources use the API group `sns.aws.upbound.io`. Namespaced resources use
`sns.aws.m.upbound.io`.

The image contains `/package.yaml` (provider metadata and custom resource definitions) and the `provider` entry point.
It serves metrics on port 8080, health probes on port 8081, and webhooks on port 9443 when Crossplane supplies
certificates.

It does not serve the AWS `ProviderConfig` APIs. Those come from `dhi.io/crossplane-provider-family-aws`, which this
package depends on. See [Family provider dependency](#family-provider-dependency).

### Print the provider help

Install this image with Crossplane. It is not a stand-alone container. To check that the image starts:

```bash
docker run --rm dhi.io/crossplane-provider-aws-sns:2 --help
```

## Install the provider in Crossplane

Set `spec.package` on a `Provider` object to this image. Crossplane reads `/package.yaml` from the image and runs the
same image as the provider pod.

Authenticate `dhi.io` once, with an `ImageConfig` pull secret. Crossplane uses it for this package, the family provider,
and the provider pods. Do not also set `packagePullSecrets` on the `Provider`. Crossplane would add the secret twice and
fail to create the `Deployment` (`duplicate entries for key`). Without the `ImageConfig`, the family provider pull fails
(`UNAUTHORIZED`) and can block other pending installs.

1. Create the pull secret in the Crossplane namespace (`crossplane-system` by default):

   ```bash
   kubectl create secret docker-registry dhi-pull-secret \
     --namespace crossplane-system \
     --docker-server=dhi.io \
     --docker-username=<username> \
     --docker-password=<access-token>
   ```

1. Create `imageconfig.yaml`:

   ```yaml
   apiVersion: pkg.crossplane.io/v1beta1
   kind: ImageConfig
   metadata:
     name: dhi-registry
   spec:
     matchImages:
       - type: Prefix
         prefix: dhi.io
     registry:
       authentication:
         pullSecretRef:
           name: dhi-pull-secret
   ```

1. Create `provider.yaml`:

   ```yaml
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-aws-sns
   spec:
     package: dhi.io/crossplane-provider-aws-sns:2
   ```

1. Apply the files:

   ```bash
   kubectl apply -f imageconfig.yaml
   kubectl apply -f provider.yaml
   kubectl get providers.pkg.crossplane.io
   ```

   Crossplane also installs the family provider. Both are ready when `INSTALLED` and `HEALTHY` are `True`.

Crossplane runs the provider pod as user and group 2000 with `runAsNonRoot`. You do not set a security context.

### Crossplane version

The package needs Crossplane v2.2 or later. Image layers use zstd. Crossplane v2.1 and earlier reject them
(`validating layers: gzip: invalid header`) and do not install the provider.

## Family provider dependency

`/package.yaml` depends on `dhi.io/crossplane-provider-family-aws`:

- Runtime and `dev` tags accept any family provider version (`>=0.0.0-0`).
- FIPS tags accept only the FIPS family provider of the same version. Tag `2.9.0-fips` needs family tag `2.9.0-fips`.

Crossplane matches only the path `dhi.io/crossplane-provider-family-aws`. An upstream family provider, for example
`xpkg.crossplane.io/crossplane-contrib/provider-family-aws`, does not satisfy the dependency. Do not install a second
family provider. The two collide on the `ProviderConfig` custom resource definition. See
[Migrate from the upstream provider](#migrate-from-the-upstream-provider).

### Install the runtime variant

A runtime tag such as `2` makes Crossplane install the newest non-FIPS `dhi.io/crossplane-provider-family-aws`. You do
not install the family provider yourself. A FIPS family provider that is already installed from that path also satisfies
a runtime tag.

### Install a FIPS variant

A FIPS tag needs family tag `<version>-fips` (the Debian FIPS family image), for example `2.9.0-fips`. The Alpine FIPS
family tag, such as `2.9.0-alpine3.24-fips`, does not satisfy the dependency. Use the Debian FIPS family image with FIPS
service providers on Debian and on Alpine.

Install the FIPS family provider before the service provider. If `dhi.io/crossplane-provider-family-aws:<version>-fips`
is not published yet, the dependency does not resolve and can block other installs.

1. `provider-family-fips.yaml` (same version as the service provider):

   ```yaml
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-family-aws
   spec:
     package: dhi.io/crossplane-provider-family-aws:2.9.0-fips
   ```

1. `provider-fips.yaml` (full version tag):

   ```yaml
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-aws-sns
   spec:
     package: dhi.io/crossplane-provider-aws-sns:2.9.0-fips
   ```

1. Apply the family provider first:

   ```bash
   kubectl apply -f provider-family-fips.yaml
   kubectl apply -f provider-fips.yaml
   ```

### Upgrade a FIPS variant

Crossplane does not upgrade a family provider that is already installed. Upgrade the family provider to the new
`<version>-fips` tag and wait until it is healthy, then upgrade the service provider. If you upgrade the service
provider first, its new revision reports that the installed family provider does not match its version constraint.

### Install from a mirror

Keep `dhi.io` in `spec.package`. Crossplane matches the family dependency on the path
`dhi.io/crossplane-provider-family-aws` only. A `Provider` that names your registry directly installs, but the family
dependency does not resolve.

Copy this image and `dhi.io/crossplane-provider-family-aws` to the same prefix in your registry, for example
`registry.example.com/dhi/`, and keep the tags. Create a pull secret for your registry (this example uses
`mirror-pull-secret`). Apply two `ImageConfig` objects. The first rewrites `dhi.io/`. The second authenticates the
rewritten prefix. Do not set `packagePullSecrets`.

```yaml
apiVersion: pkg.crossplane.io/v1beta1
kind: ImageConfig
metadata:
  name: dhi-mirror-rewrite
spec:
  matchImages:
    - type: Prefix
      prefix: dhi.io/
  rewriteImage:
    prefix: registry.example.com/dhi/
---
apiVersion: pkg.crossplane.io/v1beta1
kind: ImageConfig
metadata:
  name: dhi-mirror-auth
spec:
  matchImages:
    - type: Prefix
      prefix: registry.example.com/dhi/
  registry:
    authentication:
      pullSecretRef:
        name: mirror-pull-secret
```

The `Provider` object still uses `dhi.io/crossplane-provider-aws-sns:2`. `kubectl get providers` shows `dhi.io`.
`status.resolvedPackage` shows the path in your registry.

### Migrate from the upstream provider

An upstream service provider runs with an upstream family provider, usually named
`crossplane-contrib-provider-family-aws` or `upbound-provider-family-aws`. Do not change only the service
`spec.package`. Crossplane would install a second family provider from `dhi.io`, and that provider stays unhealthy
because the upstream family provider owns the `ProviderConfig` custom resource definitions.

Move the existing family `Provider` to `dhi.io` first. Its new revision keeps your `ProviderConfig` objects and managed
resources. Do this for the family provider and the service providers together. The example uses `2.9.0`. For FIPS, use
`2.9.0-fips` on both.

1. Create the pull secret and `ImageConfig`, as in
   [Install the provider in Crossplane](#install-the-provider-in-crossplane).

1. List the providers: `kubectl get providers.pkg.crossplane.io`.

1. Stop dependency resolution on every AWS service provider, including ones you are not moving yet:

   ```bash
   kubectl patch providers.pkg.crossplane.io provider-aws-sns --type=merge \
     -p '{"spec":{"skipDependencyResolution":true}}'
   ```

1. Point the existing family `Provider` at `dhi.io`. Use your object's name and the service provider's version:

   ```bash
   kubectl patch providers.pkg.crossplane.io crossplane-contrib-provider-family-aws --type=merge \
     -p '{"spec":{"package":"dhi.io/crossplane-provider-family-aws:2.9.0"}}'
   ```

   Wait until `HEALTHY` is `True`. Upstream service providers keep working with the `dhi.io` family provider.

1. Point the service provider at this image and wait until it is healthy:

   ```bash
   kubectl patch providers.pkg.crossplane.io provider-aws-sns --type=merge \
     -p '{"spec":{"package":"dhi.io/crossplane-provider-aws-sns:2.9.0"}}'
   ```

1. Turn dependency resolution back on for the provider you moved:

   ```bash
   kubectl patch providers.pkg.crossplane.io provider-aws-sns --type=merge \
     -p '{"spec":{"skipDependencyResolution":false}}'
   ```

Leave `skipDependencyResolution: true` on each upstream service provider until you move it. If you turn it off early,
the new revision reports `missing dependencies` and Crossplane stops its pod. Set `skipDependencyResolution` to `true`
again to recover.

## Configure AWS credentials

The family provider's `ProviderConfig` tells service providers how to sign in to AWS. This example uses an access key.
For production, use IRSA or EKS Pod Identity. See the
[upstream authentication guide](https://github.com/crossplane-contrib/provider-upjet-aws/blob/main/AUTHENTICATION.md).

1. Write `aws-credentials.txt`:

   ```ini
   [default]
   aws_access_key_id=<access-key-id>
   aws_secret_access_key=<secret-access-key>
   ```

1. Create the secret:

   ```bash
   kubectl create secret generic aws-credentials \
     --namespace crossplane-system \
     --from-file=credentials=./aws-credentials.txt
   ```

1. Apply a `ProviderConfig`:

   ```yaml
   apiVersion: aws.upbound.io/v1beta1
   kind: ProviderConfig
   metadata:
     name: default
   spec:
     credentials:
       source: Secret
       secretRef:
         namespace: crossplane-system
         name: aws-credentials
         key: credentials
   ```

### credential_process is not supported

A `credential_process` profile makes the AWS SDK run the command with `sh -c`. Runtime and FIPS runtime variants have no
shell, so the command fails.

Use `Secret`, `IRSA`, or `PodIdentity` without `credential_process`. To keep `credential_process`, build your own
provider image and use the `dev` variant only as a build stage, so the image has a shell and the credential command. Do
not install a `dev` variant as the provider package. `dev` variants are build-time images.

## Create a managed resource

This example creates an SNS topic in `us-east-1`. It uses the `ProviderConfig` named `default`. Save it as `topic.yaml`:

```yaml
apiVersion: sns.aws.upbound.io/v1beta1
kind: Topic
metadata:
  name: example-topic
spec:
  forProvider:
    region: us-east-1
  providerConfigRef:
    name: default
```

```bash
kubectl apply -f topic.yaml
kubectl get topics.sns.aws.upbound.io example-topic
```

The topic exists in AWS when `READY` and `SYNCED` are `True`. For other resources, see the
[upstream repository](https://github.com/crossplane-contrib/provider-upjet-aws).

## Non-hardened images vs. Docker Hardened Images

- **Package reference.** Change `spec.package` from `xpkg.crossplane.io/crossplane-contrib/provider-aws-sns:<version>`
  or `xpkg.upbound.io/upbound/provider-aws-sns:<version>` to `dhi.io/crossplane-provider-aws-sns:2`. Move an upstream
  family provider too. See [Migrate from the upstream provider](#migrate-from-the-upstream-provider).
- **Registry access.** `dhi.io` needs a pull secret in an `ImageConfig`. See
  [Install the provider in Crossplane](#install-the-provider-in-crossplane).
- **Family provider.** Upstream depends on `xpkg.crossplane.io/crossplane-contrib/provider-family-aws`. This image
  depends on `dhi.io/crossplane-provider-family-aws`. FIPS tags pin the same FIPS version. See
  [Family provider dependency](#family-provider-dependency).
- **Shell.** Upstream has `bash`. This runtime variant does not, so `credential_process` fails. See
  [credential_process is not supported](#credential_process-is-not-supported).
- **Upbound Marketplace.** This image has no `/.up/examples.yaml` and no Upbound Marketplace layers. A `Provider` object
  does not need them.
- **Crossplane version.** Crossplane v2.2 or later. See [Crossplane version](#crossplane-version).

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
