# syntax=docker/dockerfile:1
FROM php:8.3-cli

# Install system dependencies with apt cache mount
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y \
    git \
    bash \
    zsh \
    jq \
    vim \
    sudo \
    nano \
    curl \
    libzip-dev \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libicu-dev \
    libxml2-dev \
    libxslt-dev \
    libpq-dev \
    libonig-dev \
    build-essential \
    procps \
    file

# Install Composer globally
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    bcmath \
    ftp \
    gd \
    intl \
    mbstring \
    mysqli \
    opcache \
    pcntl \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    soap \
    sockets \
    zip

# Install PECL extensions
RUN pecl install apcu redis xdebug && \
    docker-php-ext-enable apcu redis xdebug

# Configure PHP for development
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/development.ini && \
    echo "display_errors = On" >> /usr/local/etc/php/conf.d/development.ini && \
    echo "display_startup_errors = On" >> /usr/local/etc/php/conf.d/development.ini && \
    echo "error_reporting = E_ALL" >> /usr/local/etc/php/conf.d/development.ini

# Configure Xdebug for VS Code/Cursor
# Note: xdebug.log path will be set via XDEBUG_CONFIG env var
RUN echo "xdebug.mode=develop,debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Create vscode user (matches devcontainer features)
# Set default shell to zsh (common-utils feature would do this, but we're installing it in Dockerfile)
RUN groupadd -r vscode && useradd -r -g vscode -m -s /usr/bin/zsh vscode && \
    mkdir -p /home/vscode/.devcontainer/logs && \
    mkdir -p /home/vscode/.composer && \
    chown -R vscode:vscode /home/vscode

# Ensure vscode user has sudo access
RUN echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode && \
    chmod 0440 /etc/sudoers.d/vscode

# Install Homebrew as vscode user with cache mount
# Create Homebrew directory structure with proper ownership
# Cache mounts will overlay these directories, so we ensure parent structure exists
RUN mkdir -p /home/linuxbrew/.linuxbrew/var/cache && \
    mkdir -p /home/vscode/.cache/Homebrew && \
    chown -R vscode:vscode /home/linuxbrew /home/vscode/.cache

USER vscode
WORKDIR /home/vscode

# Install Homebrew using the official installer with cache mount
# The installer will use sudo internally, which is why vscode has sudo access
RUN --mount=type=cache,target=/home/vscode/.cache/Homebrew,uid=1000,gid=1000 \
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || exit 1

# Set Homebrew prefix and configure environment
ENV BREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV PATH="${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1

# Install Homebrew packages with cache mount
# Cache mounts create directories with root ownership, so we fix ownership before brew operations
RUN --mount=type=cache,target=${BREW_PREFIX}/var/cache,uid=1000,gid=1000 \
    --mount=type=cache,target=/home/vscode/.cache/Homebrew,uid=1000,gid=1000 \
    sudo chown -R vscode:vscode ${BREW_PREFIX} /home/vscode/.cache && \
    eval "$(${BREW_PREFIX}/bin/brew shellenv)" && \
    brew install kubectl helm vault-cli mysql-client redis fnm gh awscli fzf bind netcat just

# Install composer-link plugin globally
RUN composer global config --no-plugins allow-plugins.sandersander/composer-link true && \
    composer global require sandersander/composer-link
