## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/crossplane-provider-family-aws:<tag>`
- Mirrored image: `<your-namespace>/dhi-crossplane-provider-family-aws:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Crossplane Provider Family AWS image

This Docker Hardened Crossplane Provider Family AWS image is a Crossplane package. It contains the family provider of
the Crossplane provider for AWS. The family provider serves the AWS `ProviderConfig`, `ClusterProviderConfig`, and
`ProviderConfigUsage` APIs. The AWS service providers of the same family, for example the providers for S3, IAM, and
RDS, use these APIs to find their AWS credentials. The service providers are separate packages. They are not in this
image.

The image has these parts:

- The Crossplane package file `/package.yaml`. It holds the `Provider` metadata and the five custom resource definitions
  for the AWS configuration APIs.
- The provider binary. The default entry point is `provider`.
- The license texts of the Go modules in the provider binary, in
  `/usr/share/licenses/crossplane-provider-aws-2-config/`. The FIPS variants use the directory
  `crossplane-provider-aws-2-config-fips` instead.

The provider serves metrics on port 8080 and health probes on port 8081. When Crossplane gives it certificates, the
provider also serves conversion webhooks on port 9443.

### Print the provider help

You install this image in a Kubernetes cluster with Crossplane. You do not run it as a stand-alone container. To check
that the image starts, print the help text:

```bash
docker run --rm dhi.io/crossplane-provider-family-aws:2 --help
```

## Install the provider in Crossplane

Crossplane installs a provider from a `Provider` object. The `spec.package` field of this object is the image reference.
Crossplane reads `/package.yaml` from the image and then runs the same image as the provider pod.

The `dhi.io` registry needs authentication. Crossplane must have a pull secret.

1. Create the pull secret in the namespace where Crossplane runs. The default namespace is `crossplane-system`.

   ```bash
   kubectl create secret docker-registry dhi-pull-secret \
     --namespace crossplane-system \
     --docker-server=dhi.io \
     --docker-username=<username> \
     --docker-password=<access-token>
   ```

1. Create a file named `provider.yaml` with the `Provider` object. Use the pull secret in `packagePullSecrets`.

   ```yaml
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-family-aws
   spec:
     package: dhi.io/crossplane-provider-family-aws:2
     packagePullSecrets:
       - name: dhi-pull-secret
   ```

1. Apply the file and check the provider:

   ```bash
   kubectl apply -f provider.yaml
   kubectl get providers.pkg.crossplane.io
   ```

   The provider is ready when the `INSTALLED` and `HEALTHY` columns show `True`.

Crossplane runs the provider pod as user and group 2000 and sets `runAsNonRoot`. This replaces the user of the image.
You do not need to change the security context.

### Crossplane version

The package needs Crossplane v1.13 or later, because the layers of the image use zstd compression and earlier versions
use a registry library without zstd support. Use Crossplane v2.2 or later if you can. Crossplane v1 and v2.0 and v2.1
read every layer of a package image before they use `package.yaml`. The provider binary in this image is about 1 GB, so
the install takes a long time. From v2.2, Crossplane reads only `package.yaml`.

### Configure AWS credentials

The family provider needs a `ProviderConfig` that tells the AWS service providers how to sign in to AWS. This example
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

This `ProviderConfig` is cluster-scoped. The package also serves the namespaced `ProviderConfig` and the
`ClusterProviderConfig` in the `aws.m.upbound.io` API group. These APIs are for the namespaced managed resources of
Crossplane v2.

### Use this image with AWS service providers

The upstream service providers of the family list `provider-family-aws` from their own registry as a dependency.
Crossplane matches a dependency by its registry path only, so it does not count this image as that dependency. If you
install an upstream service provider with this image, set `skipDependencyResolution: true` in the `spec` of the service
`Provider` object. If you do not, Crossplane installs a second family provider from the upstream registry, and that
install fails because this image already owns the `ProviderConfig` CRD. With `skipDependencyResolution: true`,
Crossplane does not check for a family provider, so install this image before the service providers. See the
[Crossplane provider documentation](https://docs.crossplane.io/latest/packages/providers).

## Non-hardened images vs. Docker Hardened Images

| Item                | Migration note                                                                                                                                                                                                                     |
| :------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Package reference   | Change `spec.package` in the `Provider` object from `xpkg.crossplane.io/crossplane-contrib/provider-family-aws:<version>` or `xpkg.upbound.io/upbound/provider-family-aws:<version>` to `dhi.io/crossplane-provider-family-aws:2`. |
| Registry access     | The `dhi.io` registry needs authentication. Add a pull secret to `packagePullSecrets`, as shown in [Install the provider in Crossplane](#install-the-provider-in-crossplane).                                                      |
| Shell               | The upstream image has `bash`. The runtime variant of this image has no shell. See [Use credential_process](#use-credential_process).                                                                                              |
| Upbound Marketplace | This image does not have the `/.up/examples.yaml` file or the other layers that Upbound adds for the Upbound Marketplace. The `Provider` object does not need them.                                                                |
| Crossplane version  | Crossplane v2.2 or later is recommended. See [Crossplane version](#crossplane-version).                                                                                                                                            |
| Service providers   | See [Use this image with AWS service providers](#use-this-image-with-aws-service-providers).                                                                                                                                       |

### Use credential_process

For the `IRSA` and `PodIdentity` credential sources, the provider uses the default configuration of the AWS SDK. If this
configuration selects an AWS profile that has a `credential_process` setting, the SDK runs the command with `sh -c`. The
runtime variant has no shell, so the command fails. The SDK also needs the credential command itself in the image.

To use `credential_process`, use a `dev` variant as the package. The `dev` variants include `bash`. If the credential
command is not in the image, build your own image on top of the `dev` variant to add it, and use that image in
`spec.package`. This example uses the `dev` variant as the package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-family-aws
spec:
  package: dhi.io/crossplane-provider-family-aws:2-dev
  packagePullSecrets:
    - name: dhi-pull-secret
```

The `dev` variants run as root, but Crossplane runs the provider pod as user 2000. Make sure that user 2000 can run your
credential command.

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
