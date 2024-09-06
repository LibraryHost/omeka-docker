FROM php:7.4-apache

MAINTAINER Braydon Justice <braydon.justice@1268456bcltd.ca>

RUN a2enmod rewrite

ARG version="3.1.2"
ARG port="226"

ENV version $version

ENV port $port

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

COPY ./omeka-$version.zip /var/www/

# Add the Omeka Classic code
RUN unzip -q /var/www/omeka-$version.zip -d /var/www/ \
&&  rm -rf /var/www/html/ \
&&  mv /var/www/omeka-$version/ /var/www/html \
&&  rm /var/www/html/db.ini \
&&  ln -s /var/www/html/volume/db.ini /var/www/html/db.ini

COPY ./imagemagick-policy.xml /etc/ImageMagick/policy.xml

# Create one volume for files and set permissions
RUN rm -rf /var/www/html/files/ \
&&  ln -s /var/www/html/volume/files/ /var/www/html/files \
&&  chown -R www-data:www-data /var/www/html/

RUN sed -i "s/80/$port/g" /etc/apache2/sites-available/000-default.conf \
&&  sed -i "s/80/$port/g" /etc/apache2/sites-enabled/000-default.conf \
&&  sed -i "s/Listen 80/Listen $port/g" /etc/apache2/ports.conf

#RUN if [ "$type" = "classic"]; then \
#        chmod 600 /var/www/html/volume/config/db.ini; \
#    else \
#        chmod 600 /var/www/html/volume/config/database.ini; \
#    fi

# VOLUME /var/www/html/volume/

# CMD ["apache2-foreground"]
