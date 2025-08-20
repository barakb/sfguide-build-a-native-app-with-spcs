#!/bin/bash

# Prompt user for input
read -p "What is the image repository URL (SHOW IMAGE REPOSITORIES IN SCHEMA)? " repository_url

# Paths to the files
makefile="./Makefile"

# Copy files
cp $makefile.template $makefile

# Replace placeholders in Makefile file using | as delimiter
sed -i "" "s|<<repository_url>>|$repository_url|g" $makefile

echo "Placeholder values have been replaced!"

# Build and push FalkorDB image
echo "Building and pushing FalkorDB image..."
if [ -f "./build_falkordb.sh" ]; then
    ./build_falkordb.sh "$repository_url"
    echo "FalkorDB image build completed!"
else
    echo "Warning: build_falkordb.sh not found. Please run it manually with: ./build_falkordb.sh $repository_url"
fi
