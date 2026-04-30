## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a Clojure REPL

Replace `<tag>` with the image variant you want to run.

```console
$ docker run -it --rm dhi.io/clojure:<tag> clj
```

This will start an interactive Clojure REPL where you can evaluate Clojure expressions directly.

## Common use cases

### Run Clojure code directly

You can run Clojure code directly from the command line:

```console
$ docker run --rm dhi.io/clojure:<tag> clojure -e "(println (+ 1 2 3))"
6
```

### Create and run a Clojure project

Create a project directory with a `deps.edn` file:

```console
$ mkdir my-clojure-app && cd my-clojure-app
$ cat > deps.edn << 'EOF'
{:paths ["src"]
 :deps {org.clojure/clojure {:mvn/version "1.12.0"}}}
EOF
```

Create a source file:

```console
$ mkdir -p src/myapp
$ cat > src/myapp/core.clj << 'EOF'
(ns myapp.core)

(defn -main [& args]
  (println "Hello from Clojure!")
  (println "Arguments:" (pr-str args)))
EOF
```

Run your application:

```console
$ docker run --rm -v "$(pwd):/app" -w /app dhi.io/clojure:<tag> clojure -M -m myapp.core
Hello from Clojure!
Arguments: nil
```

### Using Clojure with dependencies

The image includes tools-deps (clj/clojure) for dependency management.

Create a project with external dependencies:

```console
$ mkdir json-demo && cd json-demo
$ cat > deps.edn << 'EOF'
{:paths ["src"]
 :deps {cheshire/cheshire {:mvn/version "5.13.0"}}}
EOF
```

Create a source file that uses the dependency:

```console
$ mkdir -p src/demo
$ cat > src/demo/json.clj << 'EOF'
(ns demo.json
  (:require [cheshire.core :as json]))

(defn -main [& args]
  (let [data {:name "Clojure" :type "programming language"}]
    (println "JSON output:")
    (println (json/generate-string data {:pretty true}))))
EOF
```

Run the application (dependencies will be downloaded on first run):

```console
$ docker run --rm -v "$(pwd):/app" -w /app dhi.io/clojure:<tag> clojure -M -m demo.json
```

### Building an uberjar

You can build a standalone JAR file using the built-in tools.

Add a build configuration to your `deps.edn`:

```console
$ cat > deps.edn << 'EOF'
{:paths ["src"]
 :deps {org.clojure/clojure {:mvn/version "1.12.0"}}
 :aliases
 {:build {:deps {io.github.clojure/tools.build {:mvn/version "0.10.5"}}
          :ns-default build}}}
EOF
```

Create a build script:

```console
$ cat > build.clj << 'EOF'
(ns build
  (:require [clojure.tools.build.api :as b]))

(def lib 'myapp/core)
(def version "1.0.0")
(def class-dir "target/classes")
(def uber-file "target/myapp.jar")

(defn uber [_]
  (b/copy-dir {:src-dirs ["src"] :target-dir class-dir})
  (b/compile-clj {:basis (b/create-basis {:project "deps.edn"})
                  :src-dirs ["src"]
                  :class-dir class-dir})
  (b/uber {:class-dir class-dir
           :uber-file uber-file
           :basis (b/create-basis {:project "deps.edn"})
           :main 'myapp.core}))
EOF
```

Build the uberjar:

```console
$ docker run --rm -v "$(pwd):/app" -w /app dhi.io/clojure:<tag> clojure -T:build uber
```

### Interactive development with the REPL

For development, use the dev image variant which includes additional tools:

```console
$ docker run -it --rm -v "$(pwd):/app" -w /app dhi.io/clojure:<tag> clj
```

The `clj` command provides readline support via `rlwrap` for a better interactive experience, including:

- Command history (up/down arrows)
- Line editing (left/right arrows, backspace)
- Parentheses matching

### Java interoperability

Clojure runs on the JVM and has seamless Java interop:

```console
$ docker run --rm dhi.io/clojure:<tag> clojure -e "
(println \"Java version:\" (System/getProperty \"java.version\"))
(println \"Date:\" (.toString (java.util.Date.)))
(println \"Random:\" (.nextInt (java.util.Random.) 100))
"
```

## Environment variables

| Variable    | Description                   |
| ----------- | ----------------------------- |
| `JAVA_HOME` | Path to the Java installation |

## Volumes

For persistent development, mount your project directory:

```console
$ docker run -it --rm -v "$(pwd):/app" -w /app dhi.io/clojure:<tag> clj
```

For caching Maven dependencies between container runs, mount the `.m2` directory:

```console
$ docker run -it --rm \
  -v "$(pwd):/app" \
  -v "$HOME/.m2:/home/nonroot/.m2" \
  -w /app \
  dhi.io/clojure:<tag> clojure -M -m myapp.core
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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. Docker Hardened Clojure images include FIPS-compliant variants for environments requiring
  Federal Information Processing Standards compliance.

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
