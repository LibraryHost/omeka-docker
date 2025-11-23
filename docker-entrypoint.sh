#!/bin/bash
set -e

# Trap signals for graceful shutdown
trap 'echo "Received SIGTERM, shutting down gracefully..."; apache2ctl graceful-stop; exit 0' SIGTERM SIGINT

# Validate required environment variables
if [ -z "$LH_INSTANCE_NUM" ]; then
    echo "ERROR: LH_INSTANCE_NUM environment variable is not set"
    echo "Please set it when running the container: -e LH_INSTANCE_NUM=10"
    exit 1
fi

# Validate LH_INSTANCE_NUM is a number
if ! [[ "$LH_INSTANCE_NUM" =~ ^[0-9]+$ ]]; then
    echo "ERROR: LH_INSTANCE_NUM must be a numeric value, got: $LH_INSTANCE_NUM"
    exit 1
fi

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

echo "======================================"
echo "Omeka Classic Container Startup"
echo "======================================"
echo "PHP Version: $PHP_VERSION"
echo "Omeka Version: $OMEKA_VERSION"
echo "Ghostscript Version: $GHOSTSCRIPT_VERSION"
echo "Instance Number: $LH_INSTANCE_NUM"
echo "Port: 28${LH_INSTANCE_NUM}0"
echo "======================================"

# Wait for database to be ready (if db.ini exists with connection info)
if [ -f "/host/config/db.ini" ]; then
    echo "Checking database connectivity..."
    DB_HOST=$(grep -E '^\s*host\s*=' /host/config/db.ini | sed 's/.*=\s*"\(.*\)"/\1/')
    DB_USER=$(grep -E '^\s*username\s*=' /host/config/db.ini | sed 's/.*=\s*"\(.*\)"/\1/')
    DB_PASS=$(grep -E '^\s*password\s*=' /host/config/db.ini | sed 's/.*=\s*"\(.*\)"/\1/')

    if [ -n "$DB_HOST" ] && [ -n "$DB_USER" ]; then
        echo "Waiting for database at $DB_HOST..."
        WAIT_COUNT=0
        MAX_WAIT=30

        while ! mysqladmin ping -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" --silent 2>/dev/null; do
            WAIT_COUNT=$((WAIT_COUNT + 1))
            if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
                echo "WARNING: Database not responding after ${MAX_WAIT} seconds. Continuing anyway..."
                break
            fi
            echo "Waiting for database... (${WAIT_COUNT}/${MAX_WAIT})"
            sleep 1
        done

        if [ $WAIT_COUNT -lt $MAX_WAIT ]; then
            echo "Database is ready!"
        fi
    fi
fi

# Check if Omeka is already installed and verify version
VERSION_FILE="/var/www/html/.omeka_version_${OMEKA_VERSION}"
if [ -f "$VERSION_FILE" ] && [ -f "/var/www/html/index.php" ]; then
    echo "Omeka $OMEKA_VERSION is already installed (verified by $VERSION_FILE)"
elif [ -f "/var/www/html/index.php" ]; then
    echo "WARNING: Omeka installation found but version marker missing. Skipping reinstallation."
    echo "If you want to reinstall, remove /var/www/html/index.php"
else
    echo "Omeka not found, installing version $OMEKA_VERSION..."

    # Download and install Omeka Classic
    echo "Downloading Omeka $OMEKA_VERSION from GitHub..."
    curl -fsSL https://github.com/omeka/Omeka/releases/download/v${OMEKA_VERSION}/omeka-${OMEKA_VERSION}.zip -o /tmp/omeka.zip

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

    # Create version marker file for idempotency
    touch "$VERSION_FILE"
    echo "$OMEKA_VERSION" > "$VERSION_FILE"

    echo "Omeka $OMEKA_VERSION installation complete!"
fi

# Validate Apache configuration before starting
echo "Validating Apache configuration..."
if ! apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
    echo "ERROR: Apache configuration test failed!"
    apache2ctl configtest
    exit 1
fi
echo "Apache configuration is valid!"

# Execute the main container command (Apache)
echo ""
echo "======================================"
echo "Starting Apache on port 28${LH_INSTANCE_NUM}0..."
echo "======================================"
echo ""

# Start Apache in background and wait for signals
exec "$@"
