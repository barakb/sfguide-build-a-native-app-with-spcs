#!/bin/bash

# Non-interactive version of configure.sh that accepts repository URL as argument
# Usage: ./configure_auto.sh <repository_url>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <repository_url>"
    exit 1
fi

repository_url="$1"

# Paths to the files
makefile="./Makefile"

# Copy files
cp $makefile.template $makefile

# Replace placeholders in Makefile file using | as delimiter
sed -i "" "s|<<repository_url>>|$repository_url|g" $makefile

echo "Placeholder values have been replaced!"

# Build all Docker images using make
echo "Building and pushing all Docker images..."
make build push

echo "All Docker images built and pushed successfully!"
