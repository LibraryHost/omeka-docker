#!/bin/bash
set -e

# Set default Omeka version based on PHP version if not provided
if [ -z "$OMEKA_VERSION" ]; then
    if [ "$PHP_VERSION" = "5.6" ]; then
        OMEKA_VERSION="2.2.2"
        echo "No OMEKA_VERSION set, defaulting to $OMEKA_VERSION for PHP 5.6"
    else
        OMEKA_VERSION="2.7.1"
        echo "No OMEKA_VERSION set, defaulting to $OMEKA_VERSION for PHP 7.4+"
    fi
fi

# Check if Omeka is already installed
if [ ! -f "/var/www/html/index.php" ]; then
    echo "Omeka not found, installing version $OMEKA_VERSION..."

    # Download and install Omeka Classic
    echo "Downloading Omeka $OMEKA_VERSION from GitHub..."
    wget -q https://github.com/omeka/Omeka/releases/download/v${OMEKA_VERSION}/omeka-${OMEKA_VERSION}.zip -O /tmp/omeka.zip

    echo "Extracting Omeka..."
    unzip -q /tmp/omeka.zip -d /var/www/
    rm -rf /var/www/html/
    mv /var/www/omeka-${OMEKA_VERSION}/ /var/www/html
    rm /tmp/omeka.zip

    # Set up symlinks for config and persistent data
    echo "Creating symlinks to /host directories..."

    # Database configuration
    rm -f /var/www/html/db.ini
    ln -s /host/config/db.ini /var/www/html/db.ini

    # ImageMagick policy
    rm -f /etc/ImageMagick-6/policy.xml
    ln -s /host/config/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

    # Application configuration
    rm -f /var/www/html/application/config/config.ini
    ln -s /host/config/config.ini /var/www/html/application/config/config.ini

    # .htaccess
    rm -f /var/www/html/.htaccess
    ln -s /host/config/.htaccess /var/www/html/.htaccess

    # Persistent data directories
    rm -rf /var/www/html/files/ /var/www/html/themes/ /var/www/html/plugins/ /var/www/html/application/logs
    ln -s /host/files/ /var/www/html/files
    ln -s /host/themes/ /var/www/html/themes
    ln -s /host/plugins/ /var/www/html/plugins
    ln -s /host/logs/ /var/www/html/application/logs

    # Apply MySQL 8 compatibility fix (remove NO_AUTO_CREATE_USER)
    echo "Applying MySQL 8 compatibility fix..."
    sed -i 's/NO_AUTO_CREATE_USER,//g;s/,NO_AUTO_CREATE_USER//g' /var/www/html/application/libraries/Omeka/Application/Resource/Db.php

    # Apply HTTPS proxy detection fix for PHP 5.6
    if [ "$PHP_VERSION" = "5.6" ]; then
        echo "Applying HTTPS proxy detection fix for PHP 5.6..."
        cat > /tmp/https-fix.txt << 'EOF'

// Fix HTTPS detection behind load balancers
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER["HTTPS"] = "on";
}
EOF
        sed -i '1r /tmp/https-fix.txt' /var/www/html/bootstrap.php
        rm -f /tmp/https-fix.txt
    fi

    # Set proper ownership
    echo "Setting ownership to www-data..."
    chown -R www-data:www-data /var/www/html/

    echo "Omeka $OMEKA_VERSION installation complete!"
else
    echo "Omeka already installed, skipping installation."
fi

# Execute the main container command (Apache)
echo "Starting Apache..."
exec "$@"
