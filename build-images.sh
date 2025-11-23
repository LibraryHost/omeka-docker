#!/bin/bash

# Build script for creating multiple Omeka Classic Docker images
# This script builds images for various Omeka versions with appropriate PHP versions
#
# Features:
# - Supports pinned PHP versions for reproducible builds
# - Configurable Ghostscript version
# - Optional multi-platform builds (AMD64/ARM64)

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

# Default versions
GHOSTSCRIPT_VERSION="${GHOSTSCRIPT_VERSION:-10.02.1}"
MULTIPLATFORM="${MULTIPLATFORM:-false}"

# PHP version mapping (PHP major.minor -> full version)
declare -A PHP_FULL_VERSIONS
PHP_FULL_VERSIONS["5.6"]="5.6.40"
PHP_FULL_VERSIONS["7.4"]="7.4.33"

# Function to build an image
build_image() {
    local php_version=$1
    local omeka_version=$2
    local php_full_version="${PHP_FULL_VERSIONS[$php_version]}"
    local tag="sephirothkod/omeka-classic:${omeka_version}-php${php_version}"

    echo -e "${YELLOW}Building ${tag}...${NC}"
    echo "  PHP: ${php_version} (${php_full_version})"
    echo "  Ghostscript: ${GHOSTSCRIPT_VERSION}"
    echo "  Multi-platform: ${MULTIPLATFORM}"

    local build_cmd="docker"
    local build_args=(
        "build"
        "--build-arg" "PHP_VERSION=${php_version}"
        "--build-arg" "PHP_FULL_VERSION=${php_full_version}"
        "--build-arg" "OMEKA_VERSION=${omeka_version}"
        "--build-arg" "GHOSTSCRIPT_VERSION=${GHOSTSCRIPT_VERSION}"
        "-t" "${tag}"
    )

    # Add multi-platform support if enabled
    if [ "$MULTIPLATFORM" = "true" ]; then
        build_cmd="docker buildx"
        build_args+=("--platform" "linux/amd64,linux/arm64" "--push")
    fi

    build_args+=(".")

    if "${build_cmd}" "${build_args[@]}" ; then
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
    echo "  --multiplatform Enable multi-platform builds (AMD64/ARM64)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GHOSTSCRIPT_VERSION  Set Ghostscript version (default: 10.02.1)"
    echo "  MULTIPLATFORM        Enable multi-platform builds (true/false)"
    echo ""
    echo "Examples:"
    echo "  $0 --all                              # Build all versions"
    echo "  $0 --php74                            # Build only PHP 7.4 versions"
    echo "  $0 --custom 7.4 2.7.1                 # Build Omeka 2.7.1 with PHP 7.4"
    echo "  GHOSTSCRIPT_VERSION=10.03.1 $0 --all # Build with specific Ghostscript"
    echo "  $0 --multiplatform --php74            # Build PHP 7.4 for AMD64 and ARM64"
    echo ""
    echo "Multi-platform builds require Docker Buildx:"
    echo "  docker buildx create --use --name omeka-builder"
    echo ""
    exit 0
fi

# Check for multiplatform flag
if [ "$1" == "--multiplatform" ]; then
    MULTIPLATFORM=true
    shift
fi

# Validate multi-platform setup if enabled
if [ "$MULTIPLATFORM" = "true" ]; then
    echo "Multi-platform build enabled, checking Docker Buildx..."
    if ! docker buildx version &>/dev/null; then
        echo -e "${RED}ERROR: Docker Buildx is not available${NC}"
        echo "Install with: docker buildx create --use --name omeka-builder"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker Buildx is available${NC}"
    echo ""
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
