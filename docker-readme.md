# NOAS Docker Setup

This document describes how to build and run the NOAS application using a single Docker image containing both the Web UI and the Data Import components. This replaces the previous Makefile-based build process.

## Compatibility with Singularity

Using official base images (PostgreSQL, R) and packaging components into a single image (while allowing command override) makes this setup adaptable to Singularity. Key considerations remain:

*   Singularity can run the default `lighttpd` command or be explicitly told to run the `Rscript` command.
*   Environment variables are the primary way to pass configuration.
*   Volume mounts (`-v` / `--bind`) are used for data persistence and input.
*   Networking needs adaptation.

## Prerequisites

*   Docker installed and running.
*   Git (to clone the repository and get build info).

## Configuration

Configuration is handled via environment variables defined in the `.env` file located in the project root.

1.  **Create/Edit `.env` file:** Ensure it exists and set a strong `POSTGRES_PASSWORD`. Verify other settings like `POSTGRES_DB`, `POSTGRES_USER`, `DBHOST`.

**Key Variables in `.env`:**

*   `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: For the database container and application connection.
*   `DBHOST`, `DBPORT`: For application connection.
*   `NOAS_TABDIR`: Internal container path for data import (usually `/data`).
*   `NOAS_IMPORT_*`: Optional metadata/flags for the import script.
*   `INSTANCE_NAME`: Used during image build for the Web UI.

**Important:** Application code (R and PHP) needs to read database credentials directly from these environment variables.

## Build Steps

1.  **(DONE)** Adapt `lighttpd.conf`: Config updated for container environment.
2.  **(DONE)** Adapt `dbimport/funcs-utils.R`, `dbimport/main.R`, `webui/dbconn.php`: Scripts updated to use environment variables.
3.  **(DONE)** Consolidate Dockerfile: A single root `Dockerfile` now contains all build steps.
4.  **Build the Application Image:**
    ```bash
    # Get build-time args from .env (or override)
    source .env 
    GIT_HASH=$(git rev-parse HEAD)

    # Build using the root Dockerfile, tag as noas/app
    docker build -t noas/app \
      --build-arg GIT_HASH="${GIT_HASH}" \
      --build-arg INSTANCE_NAME="${INSTANCE_NAME}" \
      -f Dockerfile . 
    ```

## Running the Application

1.  **Create Docker Network & Volume:** (Only needs to be done once)
    ```bash
    docker network create noas-net
    docker volume create noas-pgdata
    ```
2.  **Run the PostgreSQL Container:**
    ```bash
    docker run -d --name postgres-db --network noas-net \
      --env-file .env \
      -v noas-pgdata:/var/lib/postgresql/data \
      --restart unless-stopped \
      postgres:11 
    ```
3.  **Run the Data Import (Initial Setup):**
    *   Run this after the first start of `postgres-db` to initialize the schema.
    *   Override the default command to run the R script.
    *   Ensure the host data directory (e.g., `./initial_data`) exists.
    ```bash
    mkdir -p ./initial_data # Create if needed

    docker run --rm --network noas-net \
      --env-file .env \
      -v "$(pwd)/initial_data":/data \
      noas/app Rscript /app/dbimport/main.R 
      # Note: Command override ^^^^^^^^^^^^^^^^^^^^^^
    ```
    *   Check output for errors.

4.  **Run the Web UI Container:**
    *   Runs the default `CMD` (lighttpd).
    *   Ensure the host `./run` directory exists for the socket mount.
    ```bash
    mkdir -p run 

    docker run -d --name webui --network noas-net \
      --env-file .env \
      -v "$(pwd)/run":"/app/run" \
      -p 8080:8080 \
      --restart unless-stopped \
      noas/app 
    ```
    *   Access the UI at `http://localhost:8080`.

5.  **Run Data Import (Subsequent Runs):**
    *   Place new TSV data in a directory (e.g., `./new_data_import`).
    *   Override the command similarly to the initial setup.
    ```bash
    docker run --rm --network noas-net \
      --env-file .env \
      -v "$(pwd)/new_data_import":/data \
      noas/app Rscript /app/dbimport/main.R 
      # Note: Command override ^^^^^^^^^^^^^^^^^^^^^^
    ```

## Stopping and Cleaning Up

*   **Stop and remove containers:**
    ```bash
    docker stop webui postgres-db
    docker rm webui postgres-db
    ```
*   **Remove network:**
    ```bash
    docker network rm noas-net
    ```
*   **Remove PostgreSQL data volume:** (WARNING: Deletes data)
    ```bash
    docker volume rm noas-pgdata
    ```
*   **Remove Docker images:**
    ```bash
    docker rmi noas/app postgres:11
    ``` 