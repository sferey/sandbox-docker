# Symfony & Docker

A template for new Symfony applications using Docker.

   * [Symfony & Docker](#symfony--docker)
      * [Default Stack](#default-stack)
      * [Features](#features)
      * [Production Guidelines](#production-guidelines)
   * [The `devops/` Directory](#the-devops-directory)
      * [`devops/environment/`](#devopsenvironment)
         * [The `base` Environment](#the-base-environment)
      * [`devops/docker/`](#devopsdocker)
   * [Host Setup](#host-setup)
      * [Source Archives](#source-archives)
      * [Secret Management](#secret-management)
   * [Create Application](#create-application)
      * [1. Build Application](#1-build-application)
         * [Tagging Images](#tagging-images)
         * [Naming Conventions](#naming-conventions)
   * [Application Containers](#application-containers)
      * [2. Start Application](#2-start-application)
      * [3. Install Application](#3-install-application)
      * [4. Run Application](#4-run-application)
   * [Miscellaneous](#miscellaneous)
      * [One-Off Commands](#one-off-commands)
      * [Debug](#debug)
      * [Verify Symfony Requirements](#verify-symfony-requirements)
      * [Doctrine Recipe](#doctrine-recipe)
   * [References](#references)
      * [Dockerfiles](#dockerfiles)

## Default Stack

- PHP-FPM
- NGINX
- MySQL (default for development)

## Features

```bash
sh -c "./install.sh; curl -I http://localhost:8080"
```

- Bare Symfony defaults
- Testing and Quality-Assurance built-in
- Out-of-the-box production optimized images
- Built-in secret management
- Multiple staging environments by design
- No hosting / release process assumptions
- Decoupled "devops"
- Reverse proxy with SSL and HTTP2 for development
- Catch-all mail for development

## Production Guidelines

- Use a persistent database service from your cloud provider
- Setup a reverse proxy for SSL termination on a load balancer

# The `devops/` Directory

The `devops/` directory holds all DevOps related concepts, thus separately from the application concern.

ℹ️ Don't mix&match `.env` files, considering each concern can rely on a different parsing technique ([ref](https://github.com/symfony/recipes/pull/487))

⚠️ Never commit secret values for _non-dev_ concerns

## `devops/environment/`

The `environment/` directory holds all the application its staging environments, each containing a `docker-compose.yaml`
file at least. Its concern is to compose the final application logic based upon infrastructural services.

The following environment variables are automatically available in `docker-compose.yaml`:

- `.env` (see [Docker Compose `.env`])
- `$COMPOSE_PROJECT_NAME` (see [Docker Compose `$COMPOSE_PROJECT_NAME`])
- `$APP_DIR`
- `$STAGING_ENV`

To customize a staging environment use:

```bash
cp -n devops/environment/dev/.env.dist devops/environment/dev/.env
```

To create a new staging environment (e.g. `prod`) use:

```bash
cp -R devops/environment/dev devops/environment/prod
```

ℹ️ Do not confuse _staging environments_ with the _application environment_ (it's a matrix where conceptually each 
application environment can run on any staging environment, either remote or locally)

👍 Consider standard [DTAP] environments a best practice (this template assumes `dev`, `test`, `accept` and `prod`
respectively)

### The `base` Environment

All environments implicitly inherit from `base` due [Docker Compose `-f`]. Consider `docker-compose` always being
invoked as such:

```
docker-compose \
    -f devops/environment/base/docker-compose.yaml \
    -f devops/environment/$STAGING_ENV/docker-compose.yaml \
    --project-directory devops/environment/$STAGING_ENV
```

Due the way Docker Compose works the `base` environment defines the minimal set of available services across all other
staging environments.

Specific services, as well as service overrides, can be placed in a staging environment its own `docker-compose.yaml`
file (e.g. only needed for `prod`).

The default services, built from the `base` Dockerfile, can be extended for a specific staging environment (e.g. `dev`)
at build-time using [Docker multi-stage builds]. The default `app` service is configured as such by default:

```yaml
# base
services:
  app:
    build:
      # ...
      target: "app-${STAGING_ENV:?}"
```

This creates a flexible build pattern where you can leverage either `ARG staging_env` and build generics into the base
image (`if/else`, `"file-${staging_env}.conf"`, etc.), or specifically within a scoped stage (e.g. `FROM app-base AS app-dev`).

👍 Avoid overriding the default build configuration (effectively it is a huge copy-paste)

👍 Don't extend from the base image directly (e.g. `FROM "${project}_app"`) (it will will use the last image built, not
the one currently being build)

## `devops/docker/`

The `docker/` directory holds all infrastructural services, each containing a `Dockerfile` at least. Its concern is to
prepare a minimal environment, required for the application to run.

ℹ️ A `Dockerfile` can obtain its targeted staging environment from a build argument (i.e. `ARG staging_env`)

👍 Consider a single service per concept a best practice, use [Docker multi-stage builds] for sub-concepts

# Host Setup

To `COPY` files from outside the build context the host OS is prepared first.

Prior to any build (to ensure freshness) `setup.sh` is automatically invoked from the following locations (in
order of execution):

- `devops/docker/<service>/setup.sh`
  - Use it to download files, create default directories, etc.
- `devops/environment/base/setup.sh`
  - Use it to build default infrastructural images from `devops/docker/`, "pre-pull" external images, etc.
- `devops/environment/<targeted-staging-env>/setup.sh`
  - Use it to build environment specific infrastructural images from `devops/docker/`, etc.

The following environment variables are automatically available:

- `.env` (see [Docker Compose `.env`])
- `$COMPOSE_PROJECT_NAME` (see [Docker Compose `$COMPOSE_PROJECT_NAME`])
- `$APP_DIR`
- `$STAGING_ENV`

To invoke the setup on-demand use:

```bash
make setup
```

ℹ️ This creates a two-way process and allows to scale infrastructure as needed (e.g. use pre-built images from your
organization's [Docker Hub] instead)

## Source Archives

During setup, the `devops/docker/archive` service creates a GIT archive from the current source code. This archive is
distributed using a minimal image (e.g `FROM scratch`) and allows application services to obtain and unpack it on demand
(e.g. `COPY --from=archive`).

Effectively this creates a final application image with source code included (e.g. production/distribution ready). For
development local volumes are configured.

## Secret Management

The `base` environment manages a `bucket.json` file with secret values per staging environment located in `devops/environment/<staging_env>/secrets/`.
The bucket is available in the container using [Docker Secrets]. By default the `APP_SECRET` key is created if not
defined.

Custom secrets can be managed using the JSON utility helper:

```bash
devops/bin/json.sh devops/environment/dev/secrets/bucket.json '{"SOME_SECRET": "default value"}'

# force overwrite value
devops/bin/json.sh -f devops/environment/dev/secrets/bucket.json '{"SOME_SECRET": "value"}'

# read value
value=$(devops/bin/json.sh -r devops/environment/dev/secrets/bucket.json SOME_SECRET)

# export .env file
devops/bin/json.sh -e devops/environment/dev/secrets/bucket.json devops/environment/dev/secrets/bucket.env
```

The [OpenSSL] binary is available using:

```bash
devops/bin/openssl.sh genrsa ...
```

ℹ️ The environment variables from `bucket.env` are sourced as real environment variables on start-up

# Create Application

Bootstrap the initial skeleton first:

```bash
# latest stable
./install.sh

# specify stable
SF=x.y ./install.sh
SF=x.y.z ./install.sh

# install Symfony full
FULL=1 ./install.sh

# with initial GIT commit
GIT=1 ./install.sh
```

ℹ️ The installer uses the [Symfony client](https://symfony.com/download) if available, or [Composer](https://getcomposer.org)
otherwise

⚠️ Cleanup the installer:

```bash
rm install.sh
```

And done 🎉, you can continue with [step 4](#4-run-application).

ℹ️ Start from [step 1](#1-build-application) after a fresh clone

## 1. Build Application

To create a default development build use:

```bash
make build
```

Build the application for a specific staging environment using:

```bash
STAGING_ENV=prod make build
```

ℹ️ The `STAGING_ENV` variable is global and can be applied to all `make` commands (`dev` by default)

### Tagging Images

After the build images are tagged `latest` by default. Any other form of tagging (e.g. semantic versioning) is out of 
scope of this template repository.

👍 Consider tagging images by VCS tag a best practice (e.g. `image:v1` is an artifact of the `v1` GIT tag)

### Naming Conventions

The default project name is `<project-dirname>_<staging-env>` by convention. Infrastructural services are "slash"
suffixed (e.g. `.../php`), whereas application services are "underscored" (e.g. `..._app` or `..._db`).

👍 Consider the project name a local reference, use `docker tag` for alternative (distribution) names (e.g. `org/product-name:v1`)

# Application Containers

Step 2-4 applies to running containers (with Docker Compose) from the images built previous (i.e. an "up&running"
application).

Conceptually we can create a containerized landscape from each staging environment's perspective, using
`STAGING_ENV=prod make start` (see below).

The good part is, it uses the production optimized images (thus great for local testing). The bad part
however is, this may work completely different for the true production environment" (e.g. with [Kubernetes]).

See also [What is a Container Orchestrator, Anyway?](https://containerjournal.com/2017/05/29/container-orchestrator-anyway)

👍 For a truly "dockerized" setup, consider Docker Compose files the source of truth, use e.g. `devops/environment/prod/kubernetes`
to store any specific concept configurations

👍 Ultimately double configuration bookkeeping should be avoided, use environment variables, tools such as [Kompose], etc.

## 2. Start Application

To start the application locally in development mode use:

```bash
make start
```

Consider a restart to have fresh containers once started:

```bash
make restart
```

## 3. Install Application

Install the application for development using:

```bash
make install
```

Consider a refresh (build/start/install) to install the application from scratch:

```bash
make refresh
```

## 4. Run Application

Visit the application in development mode:

  - http://localhost:8080 (`$NGINX_PORT`)
  - https://localhost:8443 (`$NGINX_PORT_SSL`)

Check e-mail:

  - http://localhost:8025 (`$MAILHOG_PORT`)

Start a shell using:

```bash
make shell

# enter web service (i.e. NGINX)
SERVICE=web make shell
```

Start a MySQL client using:

```bash
make mysql
```

# Miscellaneous

## One-Off Commands

```bash
sh -c "$(make exec) app ls"
```

Alternatively, use `make run` to create a temporary container and run as `root` user by default.

```bash
sh -c "$(make run) --no-deps app whoami"
```

## Debug

Display current docker-compose configuration and/or its images using:

```bash
make composed-config
make composed-images
```

Follow service logs:

```bash
make log
```

## Verify Symfony Requirements

After any build it might be considered to verify if Symfony requirements are (still) met using:

```bash
make requirement-check
```

## Doctrine Recipe

A set of make targets for usage with [DoctrineBundle].

```bash
db-migrate:
	${app_console} doctrine:database:create --if-not-exists
	${app_console} doctrine:migrations:migrate --allow-no-migration -n
db-sync: db-migrate
	${app_console} doctrine:schema:update --force
db-fixtures: db-sync
	${app_console} doctrine:fixtures:load -n
```

# References

- https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- https://cloud.google.com/blog/products/gcp/7-best-practices-for-building-containers
- https://symfony.com/doc/current/setup/web_server_configuration.html#nginx
- https://www.lullabot.com/articles/debugging-php-email-with-mailhog

## Dockerfiles
- https://github.com/dunglas/symfony-docker/blob/master/Dockerfile
- https://github.com/api-platform/api-platform/blob/master/api/Dockerfile
- https://github.com/jakzal/docker-symfony-intl/blob/master/Dockerfile-intl

[DTAP]: https://en.wikipedia.org/wiki/Development,_testing,_acceptance_and_production
[Docker multi-stage builds]: https://docs.docker.com/develop/develop-images/multistage-build/
[Docker Compose `.env`]: https://docs.docker.com/compose/environment-variables/#the-env-file
[Docker Compose `$COMPOSE_PROJECT_NAME`]: https://docs.docker.com/compose/reference/envvars/#compose_project_name
[Docker Compose `-f`]: https://docs.docker.com/compose/extends/#multiple-compose-files
[Docker Hub]: https://hub.docker.com/
[Docker Secrets]: https://docs.docker.com/engine/swarm/secrets/#use-secrets-in-compose
[OpenSSL]: https://www.openssl.org/
[Kubernetes]: https://kubernetes.io/
[Kompose]: https://kompose.io/
[DoctrineBundle]: https://symfony.com/doc/current/bundles/DoctrineBundle/index.html
