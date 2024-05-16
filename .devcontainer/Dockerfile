FROM mcr.microsoft.com/vscode/devcontainers/universal:1.7.5-linux

#ENV PYTHONUNBUFFERED 1

# [Optional] If your requirements rarely change, uncomment this section to add them to the image.
# COPY requirements.txt /tmp/pip-tmp/
# RUN pip3 --disable-pip-version-check --no-cache-dir install -r /tmp/pip-tmp/requirements.txt \
#    && rm -rf /tmp/pip-tmp

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>


# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# # Update and install necessary packages
RUN apt-get update && \
    apt-get install -y \
    software-properties-common \
    wget \
    gnupg2 \
    lsb-release \
    apt-transport-https \
    ca-certificates \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev

# # Install R
RUN  apt-get install -y r-base

# # Install PHP
# RUN add-apt-repository ppa:ondrej/php && \
#     apt-get update && \
#     apt-get install -y php7.4

# # Install Lighttpd
# RUN apt-get update && \
#     apt-get install -y lighttpd

# Start PostgreSQL and Lighttpd services
# CMD service postgresql start && lighttpd -D -f /etc/lighttpd/lighttpd.conf
