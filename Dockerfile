# Unified Omeka Classic Docker Image
# Supports both PHP 5.6 (for older Omeka versions) and PHP 7.4 (for newer versions)
#
# Build examples:
#   docker build --build-arg PHP_VERSION=5.6 --build-arg OMEKA_VERSION=2.2.2 -t omeka-classic:2.2.2-php5.6 .
#   docker build --build-arg PHP_VERSION=7.4 --build-arg OMEKA_VERSION=2.7.1 -t omeka-classic:2.7.1-php7.4 .

ARG PHP_VERSION=7.4
FROM php:${PHP_VERSION}-apache

MAINTAINER LibraryHost <support@libraryhost.com>

ARG OMEKA_VERSION
ARG PHP_VERSION

ENV DEBIAN_FRONTEND=noninteractive

# Fix Debian Stretch repositories for PHP 5.6 (only applies if using 5.6)
RUN if [ "${PHP_VERSION}" = "5.6" ]; then \
    sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list; \
    fi

# Enable Apache rewrite module
RUN a2enmod rewrite

# Update and install base packages
RUN apt-get -qq update && apt-get -qq -y upgrade
RUN apt-get -qq update && apt-get -qq -y --no-install-recommends install \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    ffmpeg \
    libpng-dev \
    libjpeg-dev \
    libmemcached-dev \
    zlib1g-dev \
    imagemagick \
    libmagickwand-dev \
    poppler-utils \
    vim \
    wget \
    curl

# Install PHP extensions based on PHP version
# PHP 5.6 uses different syntax for gd and has mcrypt built-in
RUN if [ "${PHP_VERSION}" = "5.6" ]; then \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
    docker-php-ext-install -j$(nproc) iconv pdo pdo_mysql mysqli gd exif mcrypt; \
    else \
    docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ && \
    docker-php-ext-install -j$(nproc) iconv pdo pdo_mysql mysqli gd exif && \
    pecl install mcrypt-1.0.7 && \
    docker-php-ext-enable mcrypt; \
    fi

# Install imagick for both versions
RUN pecl install imagick && docker-php-ext-enable imagick

# Install Ghostscript
RUN mkdir -p /installs
ADD https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs926/ghostscript-9.26-linux-x86_64.tgz /installs/
RUN cd /installs && tar -xvf ghostscript-9.26-linux-x86_64.tgz
ENV PATH /installs/ghostscript-9.26-linux-x86_64:$PATH

# Compile Ghostscript from source for better compatibility
RUN apt-get -y install build-essential autoconf autogen
ADD https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs926/ghostpdl-9.26.tar.gz /installs/
RUN cd /installs && tar -xvf ghostpdl-9.26.tar.gz
RUN cd /installs/ghostpdl-9.26 && ./autogen.sh && ./configure && make -j 5 && make install

# Download and install Omeka Classic
ADD https://github.com/omeka/Omeka/releases/download/v${OMEKA_VERSION}/omeka-${OMEKA_VERSION}.zip /installs/
RUN unzip -q /installs/omeka-${OMEKA_VERSION}.zip -d /var/www/ && \
    rm /installs/omeka-${OMEKA_VERSION}.zip && \
    rm -rf /var/www/html/ && \
    mv /var/www/omeka-${OMEKA_VERSION}/ /var/www/html

# Set up symlinks to host config directory
# This allows config.ini, db.ini, and imagemagick-policy.xml to be managed on the server
RUN rm /var/www/html/db.ini && \
    ln -s /host/config/db.ini /var/www/html/db.ini && \
    rm /etc/ImageMagick-6/policy.xml && \
    ln -s /host/config/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml && \
    rm /var/www/html/application/config/config.ini && \
    ln -s /host/config/config.ini /var/www/html/application/config/config.ini && \
    rm /var/www/html/.htaccess && \
    ln -s /host/config/.htaccess /var/www/html/.htaccess

# Set up symlinks for persistent data (files, themes, plugins, logs)
RUN rm -rf /var/www/html/files/ && \
    rm -rf /var/www/html/themes/ && \
    rm -rf /var/www/html/plugins/ && \
    rm -rf /var/www/html/application/logs && \
    ln -s /host/files/ /var/www/html/files && \
    ln -s /host/themes/ /var/www/html/themes && \
    ln -s /host/plugins/ /var/www/html/plugins && \
    ln -s /host/logs/ /var/www/html/application/logs

# Apply MySQL 8 compatibility fix (removes NO_AUTO_CREATE_USER)
RUN sed -i 's/NO_AUTO_CREATE_USER,//g;s/,NO_AUTO_CREATE_USER//g' /var/www/html/application/libraries/Omeka/Application/Resource/Db.php

# Apply HTTPS proxy detection fix for older Omeka versions
COPY https-fix.txt /tmp/
RUN if [ "${PHP_VERSION}" = "5.6" ]; then \
    sed -i '1r /tmp/https-fix.txt' /var/www/html/bootstrap.php fi && \
    rm /tmp/https-fix.txt

# Set permissions
RUN chown -R www-data:www-data /var/www/html/

# Configure Apache
RUN rm -f /etc/apache2/sites-available/* && \
    rm -f /etc/apache2/sites-enabled/* && \
    rm -f /etc/apache2/conf-enabled/other-vhosts-access-log.conf && \
    rm -f /etc/apache2/conf-available/other-vhosts-access-log.conf

ADD apache-site-omeka.conf /etc/apache2/sites-available/omeka.conf
ADD apache-conf-omeka.conf /etc/apache2/conf-available/zzz-omeka.conf

RUN a2ensite omeka && \
    a2enconf zzz-omeka && \
    echo 'Listen 28${LH_INSTANCE_NUM}0' > /etc/apache2/ports.conf

# Add custom PHP settings for upload limits
COPY extra-php-ini.txt /tmp/
RUN cat /tmp/extra-php-ini.txt >> /usr/local/etc/php/php.ini-production; \

WORKDIR /var/www/html
