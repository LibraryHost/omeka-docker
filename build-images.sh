#!/bin/bash

# Build script for creating multiple Omeka Classic Docker images
# This script builds images for various Omeka versions with appropriate PHP versions

set -e  # Exit on error

echo "======================================"
echo "Omeka Classic Docker Image Builder"
echo "======================================"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to build an image
build_image() {
    local php_version=$1
    local omeka_version=$2
    local tag="sephirothkod/omeka-classic:${omeka_version}-php${php_version}"

    echo -e "${YELLOW}Building ${tag}...${NC}"

    if docker build \
        --build-arg PHP_VERSION=${php_version} \
        --build-arg OMEKA_VERSION=${omeka_version} \
        -t ${tag} \
        . ; then
        echo -e "${GREEN}✓ Successfully built ${tag}${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to build ${tag}${NC}"
        return 1
    fi
}

# Parse command line arguments
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build Omeka Classic Docker images for multiple versions"
    echo ""
    echo "Options:"
    echo "  --all           Build all predefined versions (default)"
    echo "  --php56         Build only PHP 5.6 versions"
    echo "  --php74         Build only PHP 7.4 versions"
    echo "  --custom PHP OMEKA  Build a custom version"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all                      # Build all versions"
    echo "  $0 --php74                    # Build only PHP 7.4 versions"
    echo "  $0 --custom 7.4 2.7.1         # Build Omeka 2.7.1 with PHP 7.4"
    echo ""
    exit 0
fi

# Handle custom build
if [ "$1" == "--custom" ]; then
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo -e "${RED}Error: --custom requires PHP_VERSION and OMEKA_VERSION${NC}"
        echo "Example: $0 --custom 7.4 2.7.1"
        exit 1
    fi
    build_image $2 $3
    exit $?
fi

# Track build results
total=0
successful=0
failed=0

# PHP 5.6 versions (older Omeka)
php56_versions=("2.0.2" "2.1" "2.2.2" "2.3.1" "2.4.2" "2.5")

# PHP 7.4 versions (newer Omeka)
php74_versions=("2.6.1" "2.7" "2.7.1" "2.8" "3.1.2" "3.2")

# Determine what to build
build_php56=true
build_php74=true

if [ "$1" == "--php56" ]; then
    build_php74=false
elif [ "$1" == "--php74" ]; then
    build_php56=false
fi

# Build PHP 5.6 images
if [ "$build_php56" == true ]; then
    echo ""
    echo "======================================"
    echo "Building PHP 5.6 Images"
    echo "======================================"
    echo ""

    for version in "${php56_versions[@]}"; do
        total=$((total + 1))
        if build_image "5.6" "$version"; then
            successful=$((successful + 1))
        else
            failed=$((failed + 1))
        fi
        echo ""
    done
fi

# Build PHP 7.4 images
if [ "$build_php74" == true ]; then
    echo ""
    echo "======================================"
    echo "Building PHP 7.4 Images"
    echo "======================================"
    echo ""

    for version in "${php74_versions[@]}"; do
        total=$((total + 1))
        if build_image "7.4" "$version"; then
            successful=$((successful + 1))
        else
            failed=$((failed + 1))
        fi
        echo ""
    done
fi

# Summary
echo ""
echo "======================================"
echo "Build Summary"
echo "======================================"
echo -e "Total builds:     ${total}"
echo -e "${GREEN}Successful:       ${successful}${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed:           ${failed}${NC}"
fi
echo ""

# List built images
echo "Built images:"
docker images | grep "omeka-classic" | head -20

if [ $failed -gt 0 ]; then
    exit 1
fi

exit 0
