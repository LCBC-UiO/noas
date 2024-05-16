FROM mcr.microsoft.com/vscode/devcontainers/universal:1.7.5-linux

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
