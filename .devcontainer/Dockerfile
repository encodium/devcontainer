FROM php:8.3-cli

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    bash \
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
    && rm -rf /var/lib/apt/lists/*

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
RUN echo "xdebug.mode=develop,debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.log=/tmp/xdebug.log" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Create vscode user (matches devcontainer features)
RUN groupadd -r vscode && useradd -r -g vscode -m -s /bin/bash vscode && \
    mkdir -p /home/vscode/.devcontainer-storage && \
    chown -R vscode:vscode /home/vscode

USER vscode
WORKDIR /workspace
