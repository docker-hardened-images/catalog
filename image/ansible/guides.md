## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/ansible:<tag>`
- Mirrored image: `<your-namespace>/dhi-ansible:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Ansible is a batteries-included controller CLI for playbooks and ad-hoc tasks. This image does not listen on a port.
Playbook language, modules, and configuration are documented at <https://docs.ansible.com/>.

### What's included in this Ansible image

This Docker Hardened Ansible image includes:

- `ansible-community` — Prints the Ansible community package version.
- `ansible` — Ad-hoc task runner for the Ansible community package.
- `ansible-playbook` — Runs Ansible playbooks.
- `ansible-galaxy` — Lists and installs Ansible collections and roles.
- `ansible-vault` — Encrypts and decrypts Ansible vault data.
- `ansible-config` — Displays Ansible configuration.
- `ansible-doc` — Shows documentation for Ansible modules and plugins.
- `ansible-inventory` — Displays and graphs an Ansible inventory.
- `ansible-console` — Interactive Ansible console.
- `ansible-pull` — Pulls playbooks from a repository and runs them locally. Needs the dev variant, which has a shell and
  git.

## Start an Ansible image

The image sets no entrypoint. With no arguments, the default command prints the Ansible version.

```bash
$ docker run --rm dhi.io/ansible:<tag>
```

## Run a playbook

The working directory is `/work`. Mount a directory that contains your playbook there, and mount an SSH private key at
`/home/nonroot/.ssh/id_ecdsa`. Arguments after the image name replace the default command.

The runtime image runs as UID 65532. The mounted directory must be traversable by that user, and the playbook must be
readable. Make the directory mode `0755` and the playbook mode `0644` before a read-only mount. The private key must be
mode `0600` and owned by UID 65532. OpenSSH will not use a key owned by another user.

Use an ECDSA or RSA key. Alpine FIPS variants reject Ed25519, and `ssh-keygen` creates an Ed25519 key unless you pass
`-t`.

```bash
$ mkdir -p playbook
$ ssh-keygen -t ecdsa -b 256 -f id_ecdsa -N "" -q
$ chmod 600 id_ecdsa
$ sudo chown 65532:65532 id_ecdsa
$ cat > playbook/remote.yml <<'EOF'
- hosts: all
  gather_facts: true
  tasks:
    - ansible.builtin.copy:
        dest: /tmp/dhi-ansible.txt
        content: "hi {{ ansible_distribution }}"
    - ansible.builtin.command: cat /tmp/dhi-ansible.txt
      register: greeting
    - ansible.builtin.debug:
        msg: "{{ greeting.stdout }}"
EOF
$ chmod 755 playbook
$ chmod 644 playbook/remote.yml
$ cat > start-sshd.sh <<'EOF'
#!/bin/bash
set -eux
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends openssh-server python3
mkdir -p /root/.ssh /run/sshd
cp /authorized_keys /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
ssh-keygen -A
exec /usr/sbin/sshd -D -e
EOF
$ chmod 755 start-sshd.sh
$ docker network create ansible-net
$ docker run -d --name ansible-target --network ansible-net --network-alias target \
    -v "$PWD/id_ecdsa.pub:/authorized_keys:ro" \
    -v "$PWD/start-sshd.sh:/start-sshd.sh:ro" \
    debian:trixie-slim bash /start-sshd.sh
$ until docker logs ansible-target 2>&1 | grep -q 'Server listening'; do sleep 2; done
$ docker run --rm --network ansible-net \
    -e ANSIBLE_HOST_KEY_CHECKING=False \
    -v "$PWD/playbook:/work:ro" \
    -v "$PWD/id_ecdsa:/home/nonroot/.ssh/id_ecdsa:ro" \
    dhi.io/ansible:<tag> \
    ansible-playbook -i target, -u root --private-key /home/nonroot/.ssh/id_ecdsa /work/remote.yml
$ docker rm -f ansible-target
$ docker network rm ansible-net
```

## Image differences

There is no upstream end-user container image to migrate from.

- No entrypoint is set, so arguments after the image name replace the default command.
- Runtime variants run as UID 65532 and do not include a shell. A module that runs on localhost, including `ping`,
  `copy`, `command`, and fact gathering, needs `/bin/sh` and therefore a dev variant. `ansible-pull` needs a dev variant
  as well: its first task is a local `git` task, and the runtime image has no shell and no git.
- FIPS variants restrict the SSH client to AES-GCM and AES-CTR ciphers. Stock OpenSSH servers offer
  `chacha20-poly1305@openssh.com` first, and the FIPS provider rejects it.
- Alpine FIPS variants also reject Ed25519 host keys and client keys. OpenSSH on Alpine verifies those signatures
  through libcrypto, which the FIPS provider refuses. Use an ECDSA or RSA key. `ssh-keygen` defaults to Ed25519, so pass
  `-t ecdsa` or `-t rsa`. Debian FIPS variants can still use Ed25519.
- The working directory is `/work`.
- Dev variants include `dev` in the tag, run as root, and include a shell and git.

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
