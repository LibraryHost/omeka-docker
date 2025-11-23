# Unified Omeka Classic Docker Image
# Supports both PHP 5.6 (for older Omeka versions) and PHP 7.4 (for newer versions)
#
# Build examples:
#   docker build --build-arg PHP_VERSION=5.6 --build-arg OMEKA_VERSION=2.2.2 -t omeka-classic:2.2.2-php5.6 .
#   docker build --build-arg PHP_VERSION=7.4 --build-arg OMEKA_VERSION=2.7.1 -t omeka-classic:2.7.1-php7.4 .

# ============================================================================
# Stage 1: Builder - Compile Ghostscript
# ============================================================================
ARG PHP_VERSION=7.4
FROM php:${PHP_VERSION}-apache AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies for Ghostscript
RUN apt-get -qq update && \
    apt-get -qq -y --no-install-recommends install \
        build-essential \
        autoconf \
        autogen \
        wget \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Compile Ghostscript from source
RUN mkdir -p /installs && \
    cd /installs && \
    wget -q https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs926/ghostpdl-9.26.tar.gz && \
    tar -xzf ghostpdl-9.26.tar.gz && \
    cd ghostpdl-9.26 && \
    ./autogen.sh && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /installs

# ============================================================================
# Stage 2: Final Image
# ============================================================================
FROM php:${PHP_VERSION}-apache

LABEL maintainer="Braydon Justice <braydon.justice@1268456bcltd.ca>"

ARG PHP_VERSION

# Make PHP_VERSION available at runtime for entrypoint script
ENV PHP_VERSION=${PHP_VERSION}
ENV DEBIAN_FRONTEND=noninteractive

# OMEKA_VERSION should be set at runtime via docker run -e OMEKA_VERSION=x.x.x
# If not set, defaults to 2.7.1 (PHP 7.4) or 2.2.2 (PHP 5.6)

# Fix Debian Stretch repositories for PHP 5.6 (only applies if using 5.6)
RUN if [ "${PHP_VERSION}" = "5.6" ]; then \
    sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list; \
    fi

# Enable Apache rewrite module
RUN a2enmod rewrite

# Install runtime packages only (no -dev packages yet)
RUN apt-get -qq update && \
    apt-get -qq -y upgrade && \
    apt-get -qq -y --no-install-recommends install \
        unzip \
        libfreetype6 \
        libjpeg62-turbo \
        libmcrypt4 \
        ffmpeg \
        libpng16-16 \
        zlib1g \
        libmagickwand-6.q16-6 \
        poppler-utils \
        vim \
        wget \
        curl && \
    rm -rf /var/lib/apt/lists/*

# Install -dev packages, build PHP extensions, then remove -dev packages in single layer (saves ~50-100MB)
# PHP 5.6 uses different syntax for gd and has mcrypt built-in
RUN apt-get -qq update && \
    apt-get -qq -y --no-install-recommends install \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libmagickwand-dev && \
    if [ "${PHP_VERSION}" = "5.6" ]; then \
        docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
        docker-php-ext-install -j$(nproc) iconv pdo pdo_mysql mysqli gd exif mcrypt; \
    else \
        docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ && \
        docker-php-ext-install -j$(nproc) iconv pdo pdo_mysql mysqli gd exif && \
        pecl install mcrypt-1.0.7 && \
        docker-php-ext-enable mcrypt; \
    fi && \
    pecl install imagick && \
    docker-php-ext-enable imagick && \
    apt-get purge -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libmagickwand-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Copy compiled Ghostscript from builder stage (binaries and data files)
COPY --from=builder /usr/local/bin/gs* /usr/local/bin/
COPY --from=builder /usr/local/share/ghostscript /usr/local/share/ghostscript

# Create a temporary marker file in builder if libraries exist, then conditionally copy
COPY --from=builder /usr/local/lib/ /tmp/ghostscript-libs/
RUN if ls /tmp/ghostscript-libs/libgs* 1> /dev/null 2>&1; then \
        cp -a /tmp/ghostscript-libs/libgs* /usr/local/lib/ && \
        ldconfig; \
    fi && \
    rm -rf /tmp/ghostscript-libs

# Copy and configure entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Configure Apache and PHP settings (combined layer)
COPY apache-site-omeka.conf apache-conf-omeka.conf extra-php-ini.txt /tmp/
RUN rm -f /etc/apache2/sites-available/* /etc/apache2/sites-enabled/* \
        /etc/apache2/conf-enabled/other-vhosts-access-log.conf \
        /etc/apache2/conf-available/other-vhosts-access-log.conf && \
    cp /tmp/apache-site-omeka.conf /etc/apache2/sites-available/omeka.conf && \
    cp /tmp/apache-conf-omeka.conf /etc/apache2/conf-available/zzz-omeka.conf && \
    a2ensite omeka && \
    a2enconf zzz-omeka && \
    echo 'Listen 28${LH_INSTANCE_NUM}0' > /etc/apache2/ports.conf && \
    cat /tmp/extra-php-ini.txt >> /usr/local/etc/php/php.ini-production && \
    rm -f /tmp/apache-site-omeka.conf /tmp/apache-conf-omeka.conf /tmp/extra-php-ini.txt

WORKDIR /var/www/html

# Set entrypoint to handle Omeka installation on first run
ENTRYPOINT ["docker-entrypoint.sh"]

# Default command to start Apache
CMD ["apache2-foreground"]
