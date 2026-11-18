## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/crossplane-provider-aws-sns:<tag>`
- Mirrored image: `<your-namespace>/dhi-crossplane-provider-aws-sns:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Crossplane Provider AWS SNS image

This Docker Hardened Crossplane Provider AWS SNS image is a Crossplane package. It contains the SNS service provider of
the Crossplane provider for AWS. The provider manages Amazon SNS resources, for example `Topic`, `TopicPolicy`, and
`TopicSubscription`, as Crossplane managed resources. The cluster-scoped resources are in the API group
`sns.aws.upbound.io`. The namespaced resources of Crossplane v2 are in the API group `sns.aws.m.upbound.io`.

The image has these parts:

- The Crossplane package file `/package.yaml`. It holds the `Provider` metadata and the custom resource definitions of
  the SNS managed resources.
- The provider binary. The default entry point is `provider`.
- The license texts of the Go modules in the provider binary, in `/usr/share/licenses/crossplane-provider-aws-sns-2/`.
  The FIPS variants use the directory `crossplane-provider-aws-sns-2-fips` instead.

The provider serves metrics on port 8080 and health probes on port 8081. When Crossplane gives it certificates, the
provider also serves webhooks on port 9443.

This provider does not serve the AWS `ProviderConfig` APIs. The family provider serves them. The family provider is a
separate Docker Hardened Image, `dhi.io/crossplane-provider-family-aws`. The package of this image declares a dependency
on it, so Crossplane installs it. See [Family provider dependency](#family-provider-dependency).

### Print the provider help

You install this image in a Kubernetes cluster with Crossplane. You do not run it as a stand-alone container. To check
that the image starts, print the help text:

```bash
docker run --rm dhi.io/crossplane-provider-aws-sns:2 --help
```

## Install the provider in Crossplane

Crossplane installs a provider from a `Provider` object. The `spec.package` field of this object is the image reference.
Crossplane reads `/package.yaml` from the image and then runs the same image as the provider pod.

The `dhi.io` registry needs authentication. Give the pull secret to Crossplane one time, in an `ImageConfig` object for
`dhi.io`. Crossplane uses it to pull this package and the family provider dependency, and it adds it to the provider
pods.

Do not also put this pull secret in `packagePullSecrets` of the `Provider` object. If you do, Crossplane adds the same
secret two times to the provider pod, and it cannot create the provider `Deployment` (`duplicate entries for key`). If
the `ImageConfig` does not exist, Crossplane cannot get the family provider (`UNAUTHORIZED`) and does not install it.
The failed dependency can also stop other pending dependency installs in the cluster.

1. Create the pull secret in the namespace where Crossplane runs. The default namespace is `crossplane-system`.

   ```bash
   kubectl create secret docker-registry dhi-pull-secret \
     --namespace crossplane-system \
     --docker-server=dhi.io \
     --docker-username=<username> \
     --docker-password=<access-token>
   ```

1. Create a file named `imageconfig.yaml` with the `ImageConfig` object. It gives the pull secret to Crossplane for all
   images from `dhi.io`.

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

1. Create a file named `provider.yaml` with the `Provider` object.

   ```yaml
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-aws-sns
   spec:
     package: dhi.io/crossplane-provider-aws-sns:2
   ```

1. Apply the files and check the providers:

   ```bash
   kubectl apply -f imageconfig.yaml
   kubectl apply -f provider.yaml
   kubectl get providers.pkg.crossplane.io
   ```

   Crossplane also installs the family provider. The providers are ready when the `INSTALLED` and `HEALTHY` columns show
   `True`.

Crossplane runs the provider pod as user and group 2000 and sets `runAsNonRoot`. This replaces the user of the image.
You do not need to change the security context.

### Crossplane version

The package needs Crossplane v2.2 or later. The layers of the image use zstd compression. Crossplane v2.1 and earlier
versions, for example v1.20 and v2.0, do not accept these layers. The package revision then shows
`validating layers: gzip: invalid header`, and Crossplane does not install the provider. From v2.2, Crossplane reads
only `package.yaml` from the image.

## Family provider dependency

The `/package.yaml` file of this image declares a dependency on the family provider
`dhi.io/crossplane-provider-family-aws`:

- The runtime and `dev` tags accept any version of the family provider (`>=0.0.0-0`).
- The FIPS tags accept only the FIPS family provider of the same version. For example, the tag `2.9.0-fips` needs the
  family provider tag `2.9.0-fips`.

Crossplane counts only a family provider from the path `dhi.io/crossplane-provider-family-aws`. A family provider from a
different repository path, for example `xpkg.crossplane.io/crossplane-contrib/provider-family-aws`, does not satisfy the
dependency. Do not install a second family provider. Two family providers collide on the `ProviderConfig` custom
resource definition. To move a cluster that runs the upstream family provider, see
[Migrate from the upstream provider](#migrate-from-the-upstream-provider).

### Install the runtime variant

You do not need to install the family provider. When you install a runtime tag, for example `2`, Crossplane installs the
newest release of `dhi.io/crossplane-provider-family-aws` that is not FIPS.

If a FIPS family provider from `dhi.io/crossplane-provider-family-aws` is already installed, the runtime tag accepts it.
In that case, the cluster uses the FIPS family provider.

### Install a FIPS variant

A FIPS tag needs the family provider tag `<version>-fips`, for example `2.9.0-fips`. This is the Debian FIPS family
image. Use it with the FIPS service providers on Debian and on Alpine. The Alpine FIPS family tag, for example
`2.9.0-alpine3.24-fips`, does not satisfy the dependency.

Crossplane installs the family provider if it is not installed. But Crossplane can install it only after the tag
`dhi.io/crossplane-provider-family-aws:<version>-fips` is published. Until then, the dependency does not resolve, and
other pending dependency installs in the cluster can stop. Thus, install the FIPS family provider first:

1. Create a file named `provider-family-fips.yaml`. Make sure that the family tag exists and that its version is the
   same as the version of the service provider tag.

   ```yaml
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-family-aws
   spec:
     package: dhi.io/crossplane-provider-family-aws:2.9.0-fips
   ```

1. Create a file named `provider-fips.yaml` for the service provider. Use the full version tag, so that you control when
   the version changes.

   ```yaml
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-aws-sns
   spec:
     package: dhi.io/crossplane-provider-aws-sns:2.9.0-fips
   ```

1. Apply the files in this sequence:

   ```bash
   kubectl apply -f provider-family-fips.yaml
   kubectl apply -f provider-fips.yaml
   ```

### Upgrade a FIPS variant

Crossplane does not upgrade a family provider that is already installed. When you move a FIPS service provider to a new
version, upgrade the family provider first:

1. Change `spec.package` of the family `Provider` object to the new `<version>-fips` tag. Wait until the family provider
   is healthy.
1. Change `spec.package` of the service `Provider` object to the new `<version>-fips` tag.

If you change the service provider first, the new revision of the service provider reports that the installed family
provider is not compatible with its version constraint.

### Install from a mirror

If you copy the images to your own registry, keep `dhi.io` in `spec.package` and let Crossplane rewrite the path to your
registry. The `/package.yaml` file names `dhi.io/crossplane-provider-family-aws`, and Crossplane matches the dependency
by that path only. A `Provider` object with the path of your registry installs, but its family dependency does not
resolve.

1. Copy this image and the family provider image `dhi.io/crossplane-provider-family-aws` to the same repository prefix
   in your registry, for example `registry.example.com/dhi/`. Keep the tags. Crossplane selects the family provider
   version from the tags in your registry.

1. Create a pull secret for your registry in the namespace where Crossplane runs, as in
   [Install the provider in Crossplane](#install-the-provider-in-crossplane). This example uses the name
   `mirror-pull-secret`.

1. Create a file named `imageconfig-mirror.yaml` with two `ImageConfig` objects. The first one rewrites `dhi.io/` to
   your registry. The second one gives the pull secret for your registry. Crossplane matches the pull secret against the
   rewritten path, so the second object uses the prefix of your registry, not `dhi.io`.

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

1. Create the `Provider` object with the `dhi.io` path. You do not need `packagePullSecrets`, because the second
   `ImageConfig` gives the pull secret for this package and for the family provider.

   ```yaml
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-aws-sns
   spec:
     package: dhi.io/crossplane-provider-aws-sns:2
   ```

Crossplane pulls both packages from your registry and runs both provider pods from it. The `PACKAGE` column of
`kubectl get providers.pkg.crossplane.io` still shows `dhi.io`. The `status.resolvedPackage` field shows the path in
your registry.

### Migrate from the upstream provider

A cluster that runs the upstream AWS service providers also runs the upstream family provider. Its `Provider` object is
usually `crossplane-contrib-provider-family-aws` or `upbound-provider-family-aws`. Do not change only `spec.package` of
the service provider. If you do, Crossplane installs a second family provider from `dhi.io`, and that family provider
stays unhealthy, because the upstream family provider controls the `ProviderConfig` custom resource definitions.

Instead, move the existing family `Provider` object to `dhi.io`. Its new revision takes control of the custom resource
definitions, and your `ProviderConfig` objects and managed resources stay. Do these steps for the service providers and
the family provider together. The example uses version `2.9.0`. For a FIPS variant, use the `-fips` tags, for example
`2.9.0-fips`, for the family provider and for the service provider.

1. Create the pull secret and the `ImageConfig` object, as in
   [Install the provider in Crossplane](#install-the-provider-in-crossplane).

1. Find the AWS providers in the cluster:

   ```bash
   kubectl get providers.pkg.crossplane.io
   ```

1. Stop dependency resolution on each AWS service provider in the cluster. Do this also for the service providers that
   you do not move now. Use the names from the previous step:

   ```bash
   kubectl patch providers.pkg.crossplane.io provider-aws-sns --type=merge \
     -p '{"spec":{"skipDependencyResolution":true}}'
   ```

1. Change `spec.package` of the existing family `Provider` object to the family provider from `dhi.io`. Use the name of
   your family `Provider` object from the list, and the same version as the service provider:

   ```bash
   kubectl patch providers.pkg.crossplane.io crossplane-contrib-provider-family-aws --type=merge \
     -p '{"spec":{"package":"dhi.io/crossplane-provider-family-aws:2.9.0"}}'
   ```

   Wait until the family provider shows `True` in the `HEALTHY` column. The upstream service providers continue to work
   with the family provider from `dhi.io`.

1. Change `spec.package` of the service provider to this image, and wait until it is healthy:

   ```bash
   kubectl patch providers.pkg.crossplane.io provider-aws-sns --type=merge \
     -p '{"spec":{"package":"dhi.io/crossplane-provider-aws-sns:2.9.0"}}'
   ```

1. Start dependency resolution again on the service provider that you moved:

   ```bash
   kubectl patch providers.pkg.crossplane.io provider-aws-sns --type=merge \
     -p '{"spec":{"skipDependencyResolution":false}}'
   ```

Keep `skipDependencyResolution` set to `true` on each upstream service provider until you move it to `dhi.io`. If you
start dependency resolution on an upstream service provider, its new revision does not find the upstream family provider
(`missing dependencies`), and Crossplane stops its pod. To recover, set `skipDependencyResolution` to `true` again.

## Configure AWS credentials

The family provider serves the `ProviderConfig` that tells the service providers how to sign in to AWS. This example
uses an access key in a Kubernetes secret. Use IAM roles for service accounts (IRSA) or EKS Pod Identity for production
clusters. See the
[upstream authentication guide](https://github.com/crossplane-contrib/provider-upjet-aws/blob/main/AUTHENTICATION.md).

1. Put the access key in a file named `aws-credentials.txt`:

   ```ini
   [default]
   aws_access_key_id=<access-key-id>
   aws_secret_access_key=<secret-access-key>
   ```

1. Create the secret from the file:

   ```bash
   kubectl create secret generic aws-credentials \
     --namespace crossplane-system \
     --from-file=credentials=./aws-credentials.txt
   ```

1. Create the `ProviderConfig` and apply it with `kubectl apply -f`:

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

An AWS profile with a `credential_process` setting makes the AWS SDK run the command with `sh -c`. The runtime and FIPS
runtime variants have no shell, so the command fails.

Use a different credential source, for example `Secret`, `IRSA`, or `PodIdentity` without `credential_process`. If you
must use `credential_process`, build your own provider image in a multi-stage build. Use the `dev` variant in the build
stage to get a shell and the credential command. Do not use a `dev` variant as the provider package. The `dev` variants
are build-time images.

## Create a managed resource

This example creates an SNS topic in the `us-east-1` region. The resource uses the `ProviderConfig` named `default`.
Create a file named `topic.yaml`:

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

Apply the file and check the resource:

```bash
kubectl apply -f topic.yaml
kubectl get topics.sns.aws.upbound.io example-topic
```

The topic exists in AWS when the `READY` and `SYNCED` columns show `True`. For the other SNS resources and their fields,
see the [upstream repository](https://github.com/crossplane-contrib/provider-upjet-aws).

## Non-hardened images vs. Docker Hardened Images

| Item                       | Migration note                                                                                                                                                                                                                                                                                                                                                          |
| :------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Package reference          | Change `spec.package` in the `Provider` object from `xpkg.crossplane.io/crossplane-contrib/provider-aws-sns:<version>` or `xpkg.upbound.io/upbound/provider-aws-sns:<version>` to `dhi.io/crossplane-provider-aws-sns:2`. If the cluster runs the upstream family provider, move it too. See [Migrate from the upstream provider](#migrate-from-the-upstream-provider). |
| Registry access            | The `dhi.io` registry needs authentication. Create an `ImageConfig` with a pull secret for `dhi.io`, as shown in [Install the provider in Crossplane](#install-the-provider-in-crossplane).                                                                                                                                                                             |
| Family provider dependency | The upstream package depends on `xpkg.crossplane.io/crossplane-contrib/provider-family-aws`. This image depends on `dhi.io/crossplane-provider-family-aws`, and the FIPS tags pin the same FIPS version. See [Family provider dependency](#family-provider-dependency).                                                                                                 |
| Shell                      | The upstream image has `bash`. The runtime variant of this image has no shell, so `credential_process` does not work. See [credential_process is not supported](#credential_process-is-not-supported).                                                                                                                                                                  |
| Upbound Marketplace        | This image does not have the `/.up/examples.yaml` file or the other layers that Upbound adds for the Upbound Marketplace. The `Provider` object does not need them.                                                                                                                                                                                                     |
| Crossplane version         | Crossplane v2.2 or later is necessary. See [Crossplane version](#crossplane-version).                                                                                                                                                                                                                                                                                   |

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
