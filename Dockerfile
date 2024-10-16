FROM php:7.4-apache

MAINTAINER Braydon Justice <braydon.justice@1268456bcltd.ca>

RUN a2enmod rewrite

ARG version="3.1.2"
ENV version $version

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -qq update && apt-get -qq -y upgrade
RUN apt-get -qq update && apt-get -qq -y --no-install-recommends install \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng-dev \
    libjpeg-dev \
    libmemcached-dev \
    zlib1g-dev \
    imagemagick \
    libmagickwand-dev

# Install the PHP extensions
RUN docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/
RUN docker-php-ext-install -j$(nproc) iconv pdo pdo_mysql mysqli gd exif
RUN pecl install mcrypt-1.0.7 \
&&  docker-php-ext-enable mcrypt \
&& pecl install imagick \
&& docker-php-ext-enable imagick

# COPY ./omeka-$version.zip /var/www/

# Add the Omeka Classic code
ADD https://github.com/omeka/Omeka/releases/download/v$version/omeka-$version.zip /var/www/
RUN unzip -q /var/www/omeka-$version.zip -d /var/www/ \
&&  rm -rf /var/www/html/ \
&&  mv /var/www/omeka-$version/ /var/www/html \
&&  rm /var/www/html/db.ini \
&&  ln -s /var/www/html/volume/config/db.ini /var/www/html/db.ini

COPY ./imagemagick-policy.xml /etc/ImageMagick/policy.xml

# Create one volume for files and set permissions
RUN rm -rf /var/www/html/files/ \
&&  ln -s /var/www/html/volume/files/ /var/www/html/files \
&&  chown -R www-data:www-data /var/www/html/

COPY ./startup-script.sh /var/www/startup-script.sh
RUN chmod +x /var/www/startup-script.sh
ENTRYPOINT ["/var/www/startup-script.sh"]
