FROM php:7.4-apache

MAINTAINER Braydon Justice <braydon.justice@1268456bcltd.ca>

RUN a2enmod rewrite

ENV DEBIAN_FRONTEND noninteractive
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
    wget

# Install the PHP extensions
RUN docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/
RUN docker-php-ext-install -j$(nproc) iconv pdo pdo_mysql mysqli gd exif
RUN pecl install mcrypt-1.0.7 \
&&  docker-php-ext-enable mcrypt \
&&  pecl install imagick \
&&  docker-php-ext-enable imagick

# COPY ./omeka-$version.zip /var/www/
# Install Ghostscript
RUN mkdir -p /installs
ADD https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs926/ghostscript-9.26-linux-x86_64.tgz /installs/
RUN cd /installs && tar -xvf ghostscript-9.26-linux-x86_64.tgz

ENV PATH /installs/ghostscript-9.26-linux-x86_64:$PATH

RUN apt-get -y install build-essential
ADD https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs926/ghostpdl-9.26.tar.gz /installs/
RUN cd /installs && tar -xvf ghostpdl-9.26.tar.gz
RUN apt-get -y install autoconf autogen
RUN cd /installs/ghostpdl-9.26 && ./autogen.sh && ./configure && make -j 5 && make install

#setup links
RUN rm /var/www/html/db.ini \
&&  ln -s /var/www/html/volume/config/db.ini /var/www/html/db.ini \
&&  rm /etc/ImageMagick-6/policy.xml \
&&  ln -s /var/www/html/volume/config/policy.xml /etc/ImageMagick-6/policy.xml \
&&  rm /var/www/html/application/config/config.ini \
&&  ln -s /var/www/html/volume/config/config.ini /var/www/html/application/config/config.ini \
&&  rm /var/www/html/.htaccess \
&&  ln -s /var/www/html/volume/config/.htaccess /var/www/html/.htaccess \
&&  rm /usr/local/etc/php/php.ini-production

COPY php.ini-production /usr/local/etc/php/php.ini-production

RUN sed -i 's/NO_AUTO_CREATE_USER,//g;s/,NO_AUTO_CREATE_USER//g' /var/www/html/application/libraries/Omeka/Application/Resource/Db.php

# Create one volume for files and set permissions
RUN rm -rf /var/www/html/files/ \
&&  rm -rf /var/www/html/themes/ \
&&  rm -rf /var/www/html/plugins/ \
&&  rm -rf /var/www/html/application/logs \
&&  ln -s /var/www/html/volume/files/ /var/www/html/files \
&&  ln -s /var/www/html/volume/themes/ /var/www/html/themes \
&&  ln -s /var/www/html/volume/plugins/ /var/www/html/plugins \
&&  ln -s /var/www/html/volume/logs/ /var/www/html/application/logs \
&&  ln -s /var/www/html/volume/config/ /var/www/html/config \
&&  chown -R www-data:www-data /var/www/html/

# ADD start-apache.sh /start-apache.sh
# RUN chmod +x /start-apache.sh

RUN rm /etc/apache2/sites-available/*
RUN rm /etc/apache2/sites-enabled/*
RUN rm /etc/apache2/conf-enabled/other-vhosts-access-log.conf
RUN rm /etc/apache2/conf-available/other-vhosts-access-log.conf
ADD apache-site-omeka.conf /etc/apache2/sites-available/omeka.conf
RUN a2ensite omeka
ADD apache-conf-archon.conf /etc/apache2/conf-available/zzz-omeka.conf
RUN a2enconf zzz-omeka
RUN echo 'Listen 28${LH_INSTANCE_NUM}0' > /etc/apache2/ports.conf
RUN a2enmod rewrite

# Enable verbose error reporting in the CLI (e.g. `php -f index.php`) if we need it.
RUN sed -i "s/display_errors = .*/display_errors = On/"                 /etc/php/7.4/cli/php.ini
RUN sed -i "s/display_startup_errors = .*/display_startup_errors = On/" /etc/php/7.4/cli/php.ini
RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/"            /etc/php/7.4/cli/php.ini

# Disable verbose error reporting and logging in the web app.
RUN sed -i "s/log_errors = .*/log_errors = Off/"                         /etc/php/7.4/apache2/php.ini
RUN sed -i "s/display_errors = .*/display_errors = Off/"                 /etc/php/7.4/apache2/php.ini
RUN sed -i "s/display_startup_errors = .*/display_startup_errors = Off/" /etc/php/7.4/apache2/php.ini

