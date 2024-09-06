#!/bin/sh

echo "Setting up apache on port $1"
sed -i "s/80/$1/g" /etc/apache2/sites-available/000-default.conf
sed -i "s/80/$1/g" /etc/apache2/sites-enabled/000-default.conf
sed -i "s/Listen 80/Listen $1/g" /etc/apache2/ports.conf
echo "Finished setting up apache"

echo "Starting apache"
exec /usr/local/bin/docker-php-entrypoint apache2-foreground