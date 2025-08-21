#!/bin/bash

# Build and push FalkorDB image to Snowflake Container Registry
# Usage: ./build_falkordb.sh <registry_url>

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <registry_url>"
    echo "Example: $0 myaccount-myregion.registry.snowflakecomputing.com/spcs_app/napp/img_repo"
    exit 1
fi

REGISTRY_URL=$1

# Validate the registry URL
if [[ ! "$REGISTRY_URL" =~ .*registry\.snowflakecomputing\.com.* ]]; then
    echo "Warning: Registry URL doesn't contain 'registry.snowflakecomputing.com'"
    echo "Received: $REGISTRY_URL"
    echo "Please verify this is correct."
    read -p "Continue anyway? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Build the FalkorDB image
echo "Building FalkorDB image..."
docker build -t falkordb_server ./falkordb/

# Tag the image for the registry
echo "Tagging image for registry..."
docker tag falkordb_server:latest ${REGISTRY_URL}/falkordb_server:latest

# Push to registry
echo "Pushing image to registry..."
docker push ${REGISTRY_URL}/falkordb_server:latest

echo "FalkorDB image successfully pushed to ${REGISTRY_URL}/falkordb_server:latest"
