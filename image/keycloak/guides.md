## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a Keycloak instance

To run Keycloak in production mode, you first need valid HTTPS certificates. Run the following commands to create a
self-signed certificate. This creates `tls.crt` and `tls.key` and is valid for https://localhost only.

```
mkdir -p keycloak-certs
openssl req -x509 -newkey rsa:4096 -keyout keycloak-certs/tls.key -out keycloak-certs/tls.crt -days 365 -nodes -subj "/CN=localhost"
```

Next, run the following command to start the Keycloak instance. Replace `<tag>` with the image variant you want to run.

```
docker run -p 8443:8443 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  -e KC_HTTPS_CERTIFICATE_FILE=/etc/x509/https/tls.crt \
  -e KC_HTTPS_CERTIFICATE_KEY_FILE=/etc/x509/https/tls.key \
  -e KC_HOSTNAME=localhost \
  -v $(pwd)/keycloak-certs:/etc/x509/https \
  dhi.io/keycloak:<tag> start
```

Go to **https://localhost:8443** and login using `admin` for both the username and password.

### Create an OIDC client app

This section walks you through creating a realm, adding a user, registering an OIDC client, and requesting an access
token from Keycloak. Use the Keycloak instance you created above, running on **https://localhost:8443**.

If you aren't already, login to **https://localhost:8443/admin/** using `admin` for username and password.

#### Create a Realm

Next you create a Realm, which is similar conceptually to an Azure Entra tenant. To create a Realm, select **Manage
Realms** in the top left dropdown and then **Create Realm**.

Name it `demo-realm` and then click **Create**. In top left you should see `demo-realm` denoted as the **Current realm**
you are now managing.

#### Add a User

In the left menu, go to **Users** and then **Create new user**. Enter `docker-test-user` for the **Username** field and
then click Create.

Next set a password for the user. Go to the **Credentials** tab and click **Set password**. Enter a password and uncheck
**Temporary**. Click **Save** to set the password.

#### Create an OIDC app

Next you create an OIDC client application. Go to **Clients** **Create client**. Ensure the **Client Type** field is set
to `OpenId Connect`, then enter `demo-client` for the Client ID. Then click **Next**.

In the **Capability config** screen, toggle on **Client authentication** and then check the box for **Service accounts
roles** which will allow authentication using client ID and secret. Click **Next** and then **Save**.

Now that you have a client application, go to the **Credentials** tab and copy the **Client Secret**. You use this below
along with the client ID to authenticate.

#### Get an Access Token via REST API

Use the following curl command to get an access token from your client app. Replace `<your-client-secret>` with the
secret copied from the previous step.

```bash
CLIENT_ID=demo-client
CLIENT_SECRET=<your-client-secret>
REALM=demo-realm

curl -k -s \
  -X POST "https://localhost:8443/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=openid" | jq .
```

You should see output like the following, copy the `access_token` to use in the next step.

```json
{
  "access_token": "<your-access-token>",
  "expires_in": 300,
  "refresh_expires_in": 0,
  "token_type": "Bearer",
  "id_token": "sample-id-token",
  "not-before-policy": 0,
  "scope": "openid profile email"
}
```

#### Verify the token

To verify the token works, make a call to the `userinfo` endpoint using the access token.

```bash
curl -k -H "Authorization: Bearer <your-access-token>" \
  "https://localhost:8443/realms/demo-realm/protocol/openid-connect/userinfo"
```

You should get a result like the following output which shows the subject ID.

```json
{
   "sub":"070d5d56-cd19-4e88-b218-fe1c290a98ee",
   "email_verified":false,
   "preferred_username":"service-account-demo-client"
}
```

## Image variants

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

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use the `static` image for runtime.                                                                                                                                                                                 |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | Some images, such as static, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                                       |

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
