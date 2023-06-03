# Hasura Project Setup - March 2023

This is a step by step guide to running an [Hasura-based project](https://hasura.io) on your development machine. Keep on reading and you will learn how to build a **fully automated environment** that lets you:

- Run [Postgres](https://hub.docker.com/_/postgres) and [Adminer Web Client](https://hub.docker.com/_/adminer)
- Run [Hasura Engine](https://hub.docker.com/r/hasura/graphql-engine)
- Run [Hasura Console](https://hasura.io/docs/latest/hasura-cli/commands/hasura_console/) (with FS Sync) even from [GitPod.io](https://gitpod.io/) or [GitHub Codespaces](https://github.com/features/codespaces)
- Work with multiple data projects using a [Makefile interface](./Makefile)
- Work with [SQL migrations & seeds](https://hasura.io/docs/latest/migrations-metadata-seeds/overview/)
- Work with Postgres testing framework [PGTap](https://pgtap.org/)
- Work with [Python](https://www.python.org/) scripts [automatically generated by ChatGPT](#scripting-with-chatgpt) 😎
- Easily setup the [Pagila demo db](https://github.com/devrimgunduz/pagila) and learn to work with a complex data structure
- Learn a lot of tricks around [Make](https://www.gnu.org/software/make/), [Docker](https://www.docker.com/), & [Docker Compose](https://docs.docker.com/compose/)

> 👉 I'm working this out on a Mac and will assume that you do the very same. Windows users... 😬🫣🤗

### The only requirements for running this project are:

- [Docker](https://docker.com)
- [Make](https://www.gnu.org/software/make/manual/make.html)

### For my fellow Windows users:

Working with Windows, WSL, and Docker can be a bit of a pain, even if there are ways to make it good.

💡 For simplicity sake I'm also testing this tutorial on [GitPod.io](https://gitpod.io) and [GitHub Codespaces](https://github.com/features/codespaces), and you can easily run this project by clicking the buttons below:

[![Open in GitPod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io#https://github.com/marcopeg/hasura-2303)

[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_in-GitHub_Codespaces-blue?logo=github)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=647616168)


## Table of Contents

- [Quick Start](#quick-start)
- Making of the Workspace
  - [Create `docker-compose.yml`](#create-docker-compose-project)
    - [create Postgres container](#create-postgres-container)
    - [create Adminer container](#create-adminer-container)
    - [create Hasura container](#create-hasura-container)
  - [Install Hasura CLI](#install-hasuracli)
  - [Create the Hasura State Project](#create-the-hasura-state-project)
  - [Apply the Hasura Project](#apply-the-hasura-project)
  - [Apply Hasura State at Boot](#apply-hasura-state-at-boot)
  - [Switch to the Hasura CLI Console](#switch-to-the-hasura-cli-console)
  - [The Makefile Interface](#the-makefile-interface)
  - [Working with GitPod](#working-with-gitpodio)
  - [Working with GitHub Codespaces](#working-with-github-codespaces)
- Reference & Documentation
  - [SQL Migrations](#sql-migrations)
  - [Seeding Your Data ](#seeding-your-data)
  - [Scripting With SQL](#scripting-with-sql)
  - [Scripting With Python](#scripting-with-python)
  - [Scripting With ChatGPT](#scripting-with-chatgpt)
  - [SQL Unit Testing](#sql-unit-testing)
  - [Work With Pagila Demo DB](#work-with-pagila-demo-db)
- [Work In Progress](#work-in-progress)

## Quick Start

The project's API are based on a [Makefile](https://www.gnu.org/software/make/manual/make.html);  
You can run the following commands in a terminal:

```bash
# Show the help menu
# (there are plenty of interesting commands)
make

# Start Hasura, Postgres, and Adminer
# (it also applies migrations, metadata, and seeds)
make boot

# Stop your project
# (clean also removes the data volumes)
make stop
make clean

# Create the Pagila demo dataset
make pagila-init
```

The following services will soon be available:

- Postgres on port `5432`
- [Adminer on port `8081`](http://localhost:8081)
- [Hasura Console on port `8080`](http://localhost:8080)

## Create Docker Compose Project

```yml
version: "3.8"

services:
  postgres:
  hasura:

volumes:
  postgres:
```

Main commands interface:

```bash
# Start the project:
# (Ctrl+c) to stop
docker compose up

# Start the project (in background):
docker compose up -d

# Stop a running background project:
docker compose down

# Remove the data volumes associated with the project:
docker compose down -v
```

## Create Postgres Container

Image:  
https://hub.docker.com/_/postgres

👉 Always check for the latest available version under "tags"

```yml
postgres:
  image: postgres:15-alpine
  ports:
    - "${POSTGRES_PORT:-5432}:5432"
  volumes:
    - postgres:/var/lib/postgresql/data
  environment:
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
  restart: unless-stopped
  healthcheck:
    test: timeout 1s bash -c ':> /dev/tcp/127.0.0.1/8080' || exit 1
    interval: 2s
    timeout: 1s
    retries: 20
```

We use [volumes](https://docs.docker.com/storage/volumes/) to persist the Postgres container data. This choice makes it easy to persist data across different executions of the project.

👉 Use `docker compose down -v` to perform a full cleanup of your project.

## Create Adminer Container

Adminer is a muti-database web client that allows you to connect to a Postgres instance and extensively utilize your server.

Image:  
https://hub.docker.com/_/adminer

👉 Always check for the latest available version under "tags"

```yml
adminer:
  image: adminer:4.8.1
  ports:
    - "${ADMINER_PORT:-8081}:8080"
  links:
    - postgres:db
  restart: unless-stopped
```

Todo:

- setup default credentials
- choose a good theme

## Create Hasura Container

Image:  
https://hub.docker.com/r/hasura/graphql-engine

👉 Always check for the latest available version under "tags"

```yml
hasura:
  image: hasura/graphql-engine:v2.25.1.cli-migrations-v3
  ports:
    - "${HASURA_PORT:-8080}:8080"
  environment:
    HASURA_GRAPHQL_DEV_MODE: "true"
    HASURA_GRAPHQL_ENABLE_CONSOLE: "true"
    HASURA_GRAPHQL_ADMIN_SECRET: "${HASURA_ADMIN_SECRET:-hasura}"
    HASURA_GRAPHQL_DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD:-postgres}@postgres:5432/postgres
    HASURA_GRAPHQL_ENABLED_LOG_TYPES: startup, http-log, webhook-log, websocket-log, query-log
    HASURA_GRAPHQL_ENABLE_TELEMETRY: "false"
    HASURA_GRAPHQL_INFER_FUNCTION_PERMISSIONS: "false"
  depends_on:
    postgres:
      condition: service_healthy
  restart: unless-stopped
  healthcheck:
    test: timeout 1s bash -c ':> /dev/tcp/127.0.0.1/8080' || exit 1
    interval: 2s
    timeout: 1s
    retries: 20
```

> The healthcheck is inpired by [this thread](https://github.com/hasura/graphql-engine/issues/1532#issuecomment-1161637925).

## Install HasuraCLI

[Hasura ships a CLI](https://hasura.io/docs/latest/hasura-cli/overview/) utility that we will use to automate the state management of the project.

It makes life easy for stuff like:

- running migrations
- applying metadata
- running the Development Console

👉 Read the setup documentation [here](https://hasura.io/docs/latest/hasura-cli/install-hasura-cli/).

```bash
make hasura-install
```

> 🔥 If you are running the project in _GitPod_ or _GitHub Codespaces_ this has already been done at the first boot of the environment 😎.

## Create the Hasura State Project

> This paragraph applies whenever you are starting a project from scratch. This repo ships a ready-to-use Hasura project and you should refer to the _Makefile_ API to work with it.

Create an Hasura State project in which we can store SQL migrations and the Hasura metadata:

```bash
hasura init hasura-state
```

Now take a screenshot of the current state of the Hasura server. That needs to produce the initial migration file and the initial metadata state.

SQL Migrations:

```bash
hasura migrate create "init" \
  --admin-secret hasura \
  --project hasura-state \
  --database-name default \
  --from-server \
  --schema public
```

> 😫 Hasura lacks some love with the migrations support. In this case, it doesn't create the file `down.sql` to revert this first migration.
>
> I suggest you create it with an idempotent SQL instruction in it:  
> `SELECT now()`
>
> (Hasura migrations fail in case of an empty sql file 🧐)

Hasura metadata:

```bash
hasura metadata export \
  --admin-secret hasura \
  --project hasura-state
```

## Apply the Hasura Project

> This paragraph applies whenever you are starting a project from scratch. This repo ships a ready-to-use Hasura project and you should refer to the _Makefile_ API to work with it.

Now that we have a local Hasura Project in which we can describe the desired state of our server as code, let's see the commands that you can use to migrate informations from the source-code to the server.

Check the status of the SQL migrations:

```bash
hasura migrate status \
  --admin-secret hasura \
  --project hasura-state \
  --database-name default
```

Apply any missing migration:

```bash
hasura migrate apply \
  --admin-secret hasura \
  --project hasura-state \
  --database-name default
```

Then you can apply the Hasura metadata:

```bash
hasura metadata apply \
  --admin-secret hasura \
  --project hasura-state
```

## Apply Hasura State at Boot

> This paragraph applies whenever you are starting a project from scratch. This repo ships a ready-to-use Hasura project and you should refer to the _Makefile_ API to work with it.

Now that we have an **Hasura State Project** as a codebase, it would be nice to apply it at boot time so that our APIs are ready-to-use when we run the project for the first time.

Luckily, it is just a matter of provinding 2 new _environmental variables_ to the `hasura-engine` container, then connect the sourcecode as a volume:

```yml
volumes:
  - ./hasura-state:/project
environment:
  HASURA_GRAPHQL_METADATA_DIR: "/project/metadata"
  HASURA_GRAPHQL_MIGRATIONS_DIR: "/project/migrations"
```

Now you can rest your project as much as you want, and as long you commit your changes, your state will always start fully prepared:

```bash
docker compose down -v # removes the associated volume to reset the db
docker compose up
```

## Switch to the Hasura CLI Console

Hasura ships an incredible **development experience** through its console application.

It looks exactly like the normal console, but all your activities are automatically tracked and the changes that you make on your Hasura or Postgres services are reflected in your source folder:

- Changes to the Postgres schema are stored as new migrations
- Hasura's metadata are stored as `yaml` files

Then you can re-distribute those sources to keep in sync different environments.

### From Localhost

In order to run the _Hasura Console_ with source code sync you need to install the [Hasura CLI](https://hasura.io/docs/latest/hasura-cli/install-hasura-cli/) and then start it:

```bash
make hasura-install
make hasura-console
```

👉 Then open your browser on [`http://localhost:9695`](http://localhost:9695) 👈

### From GitPod.io or GitHub Codespaces

This project is configured as so to automatically run the _Hasura Console_ with source code sync. All the details are available through the `docker-compose.xxx.yml` extension.

👉 Open your workspace public url on port `9695` 👈

> 🚧 The HasuraCLI containers runs with user `root:root` and creates files accordingly. You need to claim those files to your host user after running a bunch of changes:
> 
> ```bash
> sudo chown -R $(id -u):$(id -g) ./hasura-state
> ```

## Working with GitPod.io

I often use [GitPod.io](https://gitpod.io) to work in isolated, stateless, and fully automated discardable environments.

The cool thing about it is that most of the automation is just a _YAML_ file away:

```yml
# Workspace automation at startup:
tasks:
  - name: Boot
    command: docker compose up

# Exposed services:
ports:
  - name: Postgres
    port: 5432
    onOpen: ignore
  - name: Hasura
    port: 8080
    onOpen: open-preview
```

> If you run this project from your local VSCode you may find this command useful:
>
> ```
> gp ports list
> ```
>
> It shows the project's ports and you can easily `Ctrl + Click` to open one in your browser.

[![Open in GitPod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io#https://github.com/marcopeg/hasura-2303)

## Working With GitHub Codespaces

[GitHub Codespaces](https://github.com/features/codespaces) offer a service similar to GitPod.

> 💡 To be honest they overlap almost 100% and I use both to extend my free tier of online available workspace.

Of course, the configuration is a bit different and it is mostly based on the `.devcontainer` standard.

[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_in-GitHub_Codespaces-blue?logo=github)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=647616168)


## The Makefile Interface

From now on, we are going to issue HasuraCLI commands that need some configuration. It may become quite a pain to remember everything. 

A simple solution is to create a `Makefile` and document our **Project's APIs** in there:

```make
project?=hasura-state
passwd?=hasura

status:
  @hasura migrate status \
    --admin-secret hasura \
    --project hasura-state \
    --database-name default
```

From now on, you can open the [`Makefile`](./Makefile) and read through its comments to find meaningfull commands for your day-to-day activities.

I've added a few commands that make woring with the Hasura state a bit easier:

```bash
# Init the project
make

# Take a full screenshot of the current state
# (you may want to remove previous migrations though)
make exports
```

## Environmental Variables

If you take a look at the top of [Makefile](./Makefile) you notice a bunch of variables with their default value.

You can change any of those values on the fly when you run a command:

```bash
# Apply migrations from a different Hasura Project:
make migrate project=xxx
```

You can also create a custom file `Makefile.env` and hardcode different values in there:

```Makefile
project=xxx
db=yyy
```

This file is already _gitignored_ and works much like a normal `.env` file.

> NOTE: For a detailed documentation of each variable and its meaning please refer to the [Makefile](./Makefile) source code and comments.

## SQL Migrations

Hasura ships with an SQL migration tool and you can use it through the Make interface:

```bash
# Apply any new migration
make migrate

# Check the migrations state:
make migrate-status

# Migrate up and down
make migrate-up
make migrate-up steps=4

# Redo a bunch of migrations
make migrate-redo steps=4

# Undo all the migrations
make migrate-destroy

# Re-apply all the migrations
# (down > up all)
make migrate-rebuild

# Scaffold a new migration
make migrate-create name=foobar

# Export the an entire schema
make migrate-export schema=foo
```

## Seeding Your Data 

[[ TODO ]]

```bash
# Apply a specific seed
# > hasura-state/seeds/default/foo.sql
make seed from=foo

# Apply a specific seed to a different db
# > hasura-state/seeds/hoho/foo.sql
make seed from=foo db=hoho

# Target a different data-project
# > foo/seeds/default/default.sql
make seed project=foo
```

## Scripting With SQL

You can run simple SQL files to play around with your schema:

```sql
-- hasura-state/sql/default/foo.sql
select now();
```

You can run this with:

```bash
make query from=foo
```

## Scripting With Python

You can store python scripts into `hasura-state/scripts/foo.py` and run it as:

```bash
make py from=foo
```

If your script needs environmental variables you can pass it a:

```bash
make py from=foo env=FOO=bar
```

> NOTE: Your scripts will be executed within a Docker container that is connected to the project's network. Therefore you can use service names as DNS.

## Scripting With ChatGPT

I use [ChatGPT](https://chat.openai.com/) a lot these days.

I give **requirements** like:

```
Given the following table, generate the query to insert 20 new 
records with a randomic date within last week and a JSON payload 
that represents a football game metrics. 

CREATE TABLE "public"."demo_events" (
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "data" JSONB NOT NULL,
    PRIMARY KEY ("created_at")
);
```

and I get something like:

```sql
INSERT INTO public.demo_events (created_at, data)
SELECT
    NOW() - INTERVAL '7 days' * RANDOM() AS created_at,
    jsonb_build_object(
        'goals_scored', FLOOR(RANDOM() * 6),
        'corners', FLOOR(RANDOM() * 11),
        'yellow_cards', FLOOR(RANDOM() * 4),
        'red_cards', FLOOR(RANDOM() * 2)
    ) AS data
FROM generate_series(1, 20);
```

I can copy/paste this into Hasura's SQL editor or Admier... Or I can run my next request:

```
Give me the same result but as a python script that uses Hasura's APIs. There will be two environmental variables: HASURA_GRAPHQL_ENDPOINT and HASURA_GRAPHQL_ADMIN_SECRET.
```

I will get a - more or less - working scrypt that I can run using the `make py` command.

## SQL Unit Testing

SQL is a language, and as with any language you can run **Unit Tests**. It's even better because with SQL you have transactions so you can safely mess around even an existing db without really affecting it.

We use [PgTap](https://pgtap.org/) as testing framework.

```bash
# Run a stateless unit test session:
# (it destroys and re-create the test database)
make pgtap

# Run tests on an existing test database:
make pgtap-run

# Run only a specific test:
# > hasura-state/tests/default/foo.sql
make pgtap-run case=foo
```

## Work With Pagila Demo DB

[Pagila](https://github.com/devrimgunduz/pagila) is a **demo database** that provides schema and data for running a DVD rental business.

You can use it to practice how to work with Hasura in exposing data via GraphQL APIs.

```bash
# Creates the Pagila public schema and load default data into it
make pagila-init

# Destroy and recreate the "public" schema
# -> this is disruptive, you will loose anything you have in the public schema!
make pagila-destroy
```

## Work In Progress

- Test diffent queries using `pg_bench` through Docker.