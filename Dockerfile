FROM php:7.4-apache

MAINTAINER Braydon Justice <braydon.justice@1268456bcltd.ca>

RUN a2enmod rewrite

ARG sVersion="4.1.1"
ARG port="226"

ENV sVersion $sVersion
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
RUN docker-php-ext-install -j$(nproc) iconv pdo pdo_mysql mysqli gd
RUN pecl install mcrypt-1.0.7 \
&&  docker-php-ext-enable mcrypt \
&& pecl install imagick \
&& docker-php-ext-enable imagick

COPY ./omeka-s-$sVersion.zip /var/www/

# Add the Omeka-S code
RUN unzip -q /var/www/omeka-s-$sVersion.zip -d /var/www/ \
&&  rm /var/www/omeka-s-$sVersion.zip \
&&  rm -rf /var/www/html/ \
&&  mv /var/www/omeka-s/ /var/www/html \
&&  rm /var/www/html/config/database.ini \
&&  ln -s /var/www/html/volume/config/database.ini /var/www/html/config/database.ini

COPY ./imagemagick-policy.xml /etc/ImageMagick/policy.xml
COPY ./.htaccess /var/www/html/.htaccess

# Create one volume for files and set permissions
RUN rm -rf /var/www/html/files/ \
&&  ln -s /var/www/html/volume/files/ /var/www/html/files \
&&  chown -R www-data:www-data /var/www/html/ \
&&  chmod 600 /var/www/html/.htaccess

COPY ./startup-script.sh /var/www/startup-script.sh
RUN chmod +x /var/www/startup-script.sh
ENTRYPOINT ["/var/www/startup-script.sh"]

