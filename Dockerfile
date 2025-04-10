# Combined Dockerfile for NOAS Web UI and Data Import

# Use a specific version of rocker/r-ver for reproducibility
FROM rocker/r-ver:4.3.3

# Install combined system dependencies 
RUN apt-get update && apt-get install -y --no-install-recommends \
    # For WebUI
    lighttpd \
    php-cgi \
    php-pgsql \
    wget \
    ca-certificates \
    # For RPostgres (needed by both)
    libpq-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install combined required R packages
RUN R -e "install.packages(c('DBI', 'RPostgreSQL', 'jsonlite', 'cli'), repos='https://cloud.r-project.org/')"

# Set up the application directory
WORKDIR /app

# Copy application code and configs
COPY ./webui/ /app/webui/
COPY ./dbimport/ /app/dbimport/
COPY ./lighttpd.conf /app/lighttpd.conf

# Copy and Extract Vendored Web Assets
COPY ./3rdparty/css /tmp/assets/css
COPY ./3rdparty/js /tmp/assets/js
RUN mkdir -p /app/webui/www/css /app/webui/www/js \
    && gunzip /tmp/assets/css/*.gz && mv /tmp/assets/css/* /app/webui/www/css/ \
    && gunzip /tmp/assets/js/*.gz && mv /tmp/assets/js/* /app/webui/www/js/ \
    && rm -rf /tmp/assets

# Arguments for build-time info (used by webui)
ARG GIT_HASH="unknown"
ARG INSTANCE_NAME="default"

# Generate static_info.json (for webui)
RUN echo "{\"instance_name\": \"${INSTANCE_NAME}\", \"git_hash\": \"${GIT_HASH}\"}" > /app/webui/www/static_info.json

# Create runtime directory for PHP-FastCGI socket (used by webui/lighttpd)
# This directory is intended to be mounted from the host via -v ./run:/app/run 
# We create it here just in case, but permissions depend on the mount.
RUN mkdir -p /app/run

# Define ENV for the web UI port, default to 8080
ENV WEBUI_PORT=8080

# Expose the web UI port
EXPOSE ${WEBUI_PORT}

# Set the default command to run lighttpd (for webui)
# Pass WEBUI_PORT from container ENV to lighttpd config env
# To run the import, override the command: 
# docker run ... noas/app Rscript /app/dbimport/main.R
CMD env WEBUI_PORT=${WEBUI_PORT} lighttpd -D -f /app/lighttpd.conf 