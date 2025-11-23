# Omeka Classic Docker - Generic Multi-Version Setup

This is a unified Docker setup for Omeka Classic that supports both older versions requiring PHP 5.6 and newer versions using PHP 7.4. This eliminates the need for separate Docker configurations for different Omeka versions.

## Features

- **Multi-PHP Version Support**: Builds with either PHP 5.6 or PHP 7.4 based on build arguments
- **Runtime Omeka Installation**: Downloads the specified Omeka version on first container startup, not at build time
- **Version Flexibility**: Single image can run any Omeka version by changing the `OMEKA_VERSION` environment variable
- **Idempotent Startup**: Safe to restart containers - only downloads Omeka if not already installed
- **Unified Config Directory**: All configuration files (config.ini, db.ini, imagemagick-policy.xml, .htaccess) are stored in a single server-side config directory
- **Security Hardening**:
  - MySQL 8 compatibility fixes
  - HTTPS proxy detection for load balancers
  - ImageMagick security policies
- **Production-Ready**: Includes Ghostscript, FFmpeg, Poppler, and ImageMagick for full media processing capabilities
- **Port Configuration**: Uses LH_INSTANCE_NUM environment variable for dynamic port assignment

## Directory Structure

```
omeka-docker-classic-generic/
├── Dockerfile                    # Multi-version Dockerfile
├── README.md                     # This file
├── docker-entrypoint.sh          # Runtime Omeka installation and startup script
├── apache-site-omeka.conf        # Apache virtual host configuration
├── apache-conf-omeka.conf        # Apache general configuration
├── extra-php-ini.txt             # PHP upload/post size limits
├── php.ini-production            # PHP production configuration
└── config/                       # Server-side configuration templates
    ├── db.ini                    # Database configuration template
    ├── config.ini.template       # Omeka configuration template
    ├── .htaccess.template        # Apache rewrite rules template
    └── imagemagick-policy.xml    # ImageMagick security policies
```

## Building Images

Since Omeka is now installed at runtime, you only need to build images for each PHP version:

### For PHP 5.6 (Older Omeka Versions)

```bash
docker build \
  --build-arg PHP_VERSION=5.6 \
  -t omeka-classic:php5.6 \
  .
```

### For PHP 7.4 (Newer Omeka Versions)

```bash
docker build \
  --build-arg PHP_VERSION=7.4 \
  -t omeka-classic:php7.4 \
  .
```

### Default Values

- `PHP_VERSION` defaults to `7.4` if not specified
- `OMEKA_VERSION` is set at **runtime** (not build time) via environment variable

**Key Advantage**: A single built image (e.g., `omeka-classic:php7.4`) can run any Omeka version compatible with that PHP version. Just change the `OMEKA_VERSION` environment variable when starting the container.

## Version Compatibility Guide

| Omeka Version | Recommended PHP | Notes |
|---------------|----------------|-------|
| 2.0.x - 2.3.x | PHP 5.6 | Older versions, requires PHP 5.6 |
| 2.4.x - 2.6.x | PHP 5.6 or 7.4 | Transitional, test both |
| 2.7.x+ | PHP 7.4 | Newer versions, optimized for PHP 7.4 |

## Server-Side Configuration

### Directory Setup

On your server, create the following directory structure for each instance:

```
/var/www/[instance_name]/
├── config/
│   ├── config.ini              # Copy from config.ini.template and customize
│   ├── db.ini                  # Database credentials
│   ├── .htaccess               # Copy from .htaccess.template
│   └── imagemagick-policy.xml  # ImageMagick security policies (included)
├── files/                      # Uploaded files
├── themes/                     # Omeka themes
├── plugins/                    # Omeka plugins
└── logs/                       # Application logs
```

### Configuration Files

1. **db.ini**: Update with your database credentials
   ```ini
   [database]
   host     = "localhost"
   username = "your_db_user"
   password = "your_db_password"
   dbname   = "your_db_name"
   prefix   = "omeka_"
   charset  = "utf8"
   ```

2. **config.ini**: Copy from `config.ini.template` and customize:
   - Set `site.title`
   - Update database settings (or use db.ini)
   - Set `siteUrl` to your public URL
   - Generate random values for `session.name` and `form.secret`

3. **.htaccess**: Copy from `.htaccess.template` - usually works as-is

4. **imagemagick-policy.xml**: Provided in config directory, usually no changes needed

## Running a Container

### Using Docker Run

**With specific Omeka version:**
```bash
docker run -d \
  --name omeka-instance-name \
  --net=host \
  -e OMEKA_VERSION=2.7.1 \
  -e LH_INSTANCE_NUM=10 \
  -v /var/www/instance_name:/host \
  omeka-classic:php7.4
```

**With default Omeka version (2.7.1 for PHP 7.4, 2.2.2 for PHP 5.6):**
```bash
docker run -d \
  --name omeka-instance-name \
  --net=host \
  -e LH_INSTANCE_NUM=10 \
  -v /var/www/instance_name:/host \
  omeka-classic:php7.4
```

### Using Docker Compose

```yaml
version: '3.8'
services:
  omeka:
    image: omeka-classic:php7.4
    container_name: omeka-instance-name
    environment:
      - OMEKA_VERSION=2.7.1  # Optional - defaults to 2.7.1 for PHP 7.4
      - LH_INSTANCE_NUM=10
    volumes:
      - /var/www/instance_name:/host
    network_mode: host
    restart: unless-stopped
```

### How It Works

1. **First Startup**: Container downloads and installs Omeka based on `OMEKA_VERSION` env var
2. **Subsequent Restarts**: Detects existing installation and skips download
3. **Version Changes**: To change Omeka version, remove `/var/www/instance_name` contents and restart with new `OMEKA_VERSION`

### Port Mapping

The container uses the `LH_INSTANCE_NUM` environment variable to determine its port:
- Port formula: `28[LH_INSTANCE_NUM]0`
- Example: `LH_INSTANCE_NUM=10` → Port `28100`
- Example: `LH_INSTANCE_NUM=42` → Port `28420`

## Volume Mounting

The container expects a single volume mount at `/host` containing:

```
/host/
├── config/          # Configuration files (required)
├── files/           # Uploaded files (required)
├── themes/          # Omeka themes (required)
├── plugins/         # Omeka plugins (required)
└── logs/            # Application logs (required)
```

All these directories must exist before starting the container.

## Integration with Existing Instance Scripts

This Docker setup is compatible with the existing docker setups. The key differences:

### Old Setup
- Required separate Docker images for each Omeka version
- Omeka installed at build time
- Changing versions required rebuilding images

### New Setup
- Only 2 images needed: `omeka-classic:php5.6` and `omeka-classic:php7.4`
- Omeka installed at runtime on first container start
- Changing versions only requires updating `OMEKA_VERSION` env var and recreating container
- All config files in `/var/www/[instance]/config/`
- Same volume mounting pattern: `/var/www/[instance]:/host`
- Port numbering scheme using LH_INSTANCE_NUM

## Upgrading from Old Setups

If you have existing Omeka instances using the old Docker setups:

1. **Create config directory**:
   ```bash
   mkdir -p /var/www/[instance]/config
   ```

2. **Move configuration files**:
   ```bash
   # These files should already be symlinked to volume/config/
   # If not, move them:
   mv /var/www/[instance]/db.ini /var/www/[instance]/config/
   mv /var/www/[instance]/application/config/config.ini /var/www/[instance]/config/
   mv /var/www/[instance]/.htaccess /var/www/[instance]/config/
   ```

3. **Copy ImageMagick policy**:
   ```bash
   cp imagemagick-policy.xml /var/www/[instance]/config/
   ```

4. **Rebuild and restart container** with new image

## Troubleshooting

### Container Won't Start

1. Check that all required directories exist:
   ```bash
   ls -la /var/www/[instance]/{config,files,themes,plugins,logs}
   ```

2. Verify config files are readable:
   ```bash
   cat /var/www/[instance]/config/db.ini
   cat /var/www/[instance]/config/config.ini
   ```

### Database Connection Errors

1. Check db.ini has correct credentials
2. Verify MySQL is running and accessible
3. Ensure database and user exist

### Permission Issues

The container runs as `www-data` (UID 33). Ensure files are owned correctly:
```bash
chown -R www-data:www-data /var/www/[instance]
```

### Port Conflicts

If the calculated port is already in use, change `LH_INSTANCE_NUM` to a different value.

## Security Considerations

- Database credentials are stored in `/host/config/db.ini` inside the container
- ImageMagick policies prevent known vulnerabilities (Ghostscript, arbitrary file reads)
- HTTPS detection works correctly behind reverse proxies
- MySQL 8 compatibility is automatically handled
- Error logging is disabled in production for security

## Building Base Images

You only need to build two base images (one for each PHP version):

```bash
#!/bin/bash

# Build PHP 5.6 base image (for Omeka 2.0.x - 2.3.x)
docker build \
  --build-arg PHP_VERSION=5.6 \
  -t omeka-classic:php5.6 \
  .

# Build PHP 7.4 base image (for Omeka 2.7.x+)
docker build \
  --build-arg PHP_VERSION=7.4 \
  -t omeka-classic:php7.4 \
  .
```

Then use these base images with different `OMEKA_VERSION` environment variables to run any compatible Omeka version:

```bash
# Run Omeka 2.2.2 with PHP 5.6 base image
docker run -d -e OMEKA_VERSION=2.2.2 -e LH_INSTANCE_NUM=10 -v /var/www/instance1:/host omeka-classic:php5.6

# Run Omeka 2.7.1 with PHP 7.4 base image
docker run -d -e OMEKA_VERSION=2.7.1 -e LH_INSTANCE_NUM=20 -v /var/www/instance2:/host omeka-classic:php7.4

# Run Omeka 2.6.1 with PHP 7.4 base image (different version, same image)
docker run -d -e OMEKA_VERSION=2.6.1 -e LH_INSTANCE_NUM=30 -v /var/www/instance3:/host omeka-classic:php7.4
```

## Credits

This unified Docker setup combines the best features from:
- `brian_docker_omeka_classic` - Ubuntu-based approach with flexible versioning
- `omeka-docker-old-classic` - PHP 5.6 support and security fixes
- `omeka-docker-classic-dev` - PHP 7.4 optimization and modern configurations

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Docker logs: `docker logs [container-name]`
3. Verify configuration files are properly set up
4. Ensure your Omeka version is compatible with the chosen PHP version
