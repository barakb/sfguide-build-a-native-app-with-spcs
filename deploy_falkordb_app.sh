#!/bin/bash

# FalkorDB App Deployment Script for Snowpark Container Services (SPCS)
# This script deploys a FalkorDB-based Native App with full automation and can be run multiple times safely
# Usage: ./deploy_falkordb_app.sh [OPTIONS]

set -e

# Parse command line arguments
FORCE_REBUILD=false
FORCE_UPLOAD=false
DEV_MODE=false

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "FalkorDB App Deployment Script for Snowpark Container Services"
    echo "Deploys a graph database application with FalkorDB and router containers"
    echo ""
    echo "Options:"
    echo "  -f, --force-rebuild    Force rebuild of all Docker images even if they exist"
    echo "  -u, --force-upload     Force re-upload of application files even if they exist"
    echo "  -d, --dev              Development mode: reuse Docker images, refresh files & deployments"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Deploy in normal idempotent mode"
    echo "  $0 -d                  # Development mode: fast deploy (reuse images, fresh app)"
    echo "  $0 -f                  # Force rebuild all images and deploy"
    echo "  $0 --force-rebuild     # Force rebuild all images (long form)"
    echo "  $0 -f -u               # Force rebuild images and re-upload files"
    echo ""
    echo "Development Tips:"
    echo "  Use -d for fastest development cycles (skips time-consuming Docker builds)"
    echo "  Use -f when you've changed Dockerfile or container configuration"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force-rebuild)
            FORCE_REBUILD=true
            shift
            ;;
        -u|--force-upload)
            FORCE_UPLOAD=true
            shift
            ;;
        -d|--dev)
            DEV_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "🎯 FalkorDB App Deployment for Snowpark Container Services"
echo "==========================================================="
echo "📊 Graph Database Application with FalkorDB + Router Architecture"
if [ "$FORCE_REBUILD" = true ]; then
    echo "🔧 Force rebuild mode enabled"
fi
if [ "$FORCE_UPLOAD" = true ]; then
    echo "📤 Force upload mode enabled"  
fi
if [ "$DEV_MODE" = true ]; then
    echo "🚀 Development mode: Reusing Docker images, refreshing application deployment"
    echo "   ⏱️  Skips: Time-consuming Docker image building"
    echo "   🔄 Recreates: Application files, packages, and deployments for fresh state"
fi
echo ""

# Function to check if setup is complete
check_setup_complete() {
    # Check if the database and schema exist, and if the image repository exists
    local setup_check=$(snow sql -q "use role accountadmin; select count(*) as cnt from information_schema.schemata where schema_name = 'NAPP' and catalog_name = 'SPCS_APP';" --format CSV 2>/dev/null | tail -n +2 | tr -d '"\n\r' || echo "0")
    # Ensure we return a clean integer
    setup_check=$(echo "$setup_check" | grep -o '[0-9]*' | head -1)
    [ -z "$setup_check" ] && setup_check="0"
    echo "$setup_check"
}

# Function to check if application package exists
check_app_package_exists() {
    local pkg_check=$(snow sql -q "use role naspcs_role; show application packages like 'SPCS_APP_PKG';" 2>/dev/null | grep -c "SPCS_APP_PKG" 2>/dev/null || echo "0")
    # Ensure we return a clean integer
    pkg_check=$(echo "$pkg_check" | tr -d '\n\r' | grep -o '[0-9]*' | head -1)
    [ -z "$pkg_check" ] && pkg_check="0"
    echo "$pkg_check"
}

# Function to check if images exist in repository
check_images_exist() {
    local images_check=$(snow sql -q "use role naspcs_role; show images in image repository spcs_app.napp.img_repo;" 2>/dev/null | grep -c "falkordb_" 2>/dev/null || echo "0")
    # Ensure we return a clean integer
    images_check=$(echo "$images_check" | tr -d '\n\r' | grep -o '[0-9]*' | head -1)
    [ -z "$images_check" ] && images_check="0"
    echo "$images_check"
}

# Function to check if application files are uploaded
check_files_uploaded() {
    local files_check=$(snow sql -q "use role naspcs_role; list @spcs_app.napp.app_stage;" 2>/dev/null | grep -c "manifest.yml" 2>/dev/null || echo "0")
    # Ensure we return a clean integer
    files_check=$(echo "$files_check" | tr -d '\n\r' | grep -o '[0-9]*' | head -1)
    [ -z "$files_check" ] && files_check="0"
    echo "$files_check"
}

# Function to check if application exists
check_application_exists() {
    local app_check=$(snow sql -q "use role nac; show applications like 'FALKORDB_APP';" 2>/dev/null | grep -c "FALKORDB_APP" 2>/dev/null || echo "0")
    # Ensure we return a clean integer
    app_check=$(echo "$app_check" | tr -d '\n\r' | grep -o '[0-9]*' | head -1)
    [ -z "$app_check" ] && app_check="0"
    echo "$app_check"
}

# Function to check if compute pool exists
check_compute_pool_exists() {
    local pool_check=$(snow sql -q "use role accountadmin; show compute pools like 'POOL_NAC_CONTAINERS';" 2>/dev/null | grep -c "POOL_NAC_CONTAINERS" 2>/dev/null || echo "0")
    # Ensure we return a clean integer
    pool_check=$(echo "$pool_check" | tr -d '\n\r' | grep -o '[0-9]*' | head -1)
    [ -z "$pool_check" ] && pool_check="0"
    echo "$pool_check"
}

# Step 1: Setup (idempotent)
echo "📋 Step 1: Checking setup status..."
setup_status=$(check_setup_complete)

if [ "$setup_status" = "1" ]; then
    echo "✅ Setup already complete, skipping..."
else
    echo "🔧 Running setup (creating roles, databases, stages)..."
    snow sql -f scripts/setup.sql
    echo "✅ Setup completed!"
fi
echo ""

# Step 2: Get repository URL automatically with robust parsing
echo "🔍 Step 2: Getting repository URL automatically..."

# Use JSON format for reliable parsing
echo "Getting repository information using JSON format..."
json_output=$(snow sql --format JSON -q "use role naspcs_role; show image repositories in schema spcs_app.napp;" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$json_output" ]; then
    echo "❌ Failed to get repository information from Snowflake"
    exit 1
fi

# Extract repository URL using jq - handle nested JSON structure
repository_url=$(echo "$json_output" | jq -r '.[1][0].repository_url // empty' 2>/dev/null)

if [ ! -z "$repository_url" ] && [[ "$repository_url" =~ .*registry\.snowflakecomputing\.com.* ]]; then
    echo "✅ Extracted repository URL: $repository_url"
else
    echo "❌ Failed to extract repository URL using JSON/jq method."
    echo "JSON output for debugging:"
    echo "$json_output"
    echo "Please ensure jq is installed: brew install jq"
    exit 1
fi

# Step 3: Build and upload (idempotent)
echo "🔨 Step 3: Checking if images need to be built..."

# Check if images already exist (unless force rebuild is enabled)
skip_build=false
if [ "$FORCE_REBUILD" = true ]; then
    echo "🔄 Force rebuild enabled - rebuilding all images..."
    images_status=0  # Force rebuild by setting status to 0
elif [ "$DEV_MODE" = true ]; then
    images_status=$(check_images_exist)
    echo "🚀 Dev mode: Found $images_status existing images in repository"
    if [ "$images_status" -ge "1" ]; then
        echo "✅ Dev mode: Reusing existing images (found $images_status), skipping build to save time..."
        skip_build=true
    else
        skip_build=false
    fi
else
    images_status=$(check_images_exist)
    echo "Found $images_status existing images in repository"
    skip_build=false
fi

if [ "$skip_build" = true ] || ([ "$images_status" -ge "2" ] && [ "$FORCE_REBUILD" = false ]); then
    if [ "$DEV_MODE" = true ]; then
        echo "✅ Dev mode: Reusing existing images, skipping build to save development time..."
    else
        echo "✅ All images already exist, skipping build..."
    fi
else
    if [ "$FORCE_REBUILD" = true ]; then
        echo "🔧 Force rebuilding all images..."
    else
        echo "🔧 Building missing images..."
    fi
    
    # Verify configure.sh exists
    if [ ! -f "./configure_auto.sh" ]; then
        echo "❌ Error: configure_auto.sh not found in current directory"
        exit 1
    fi

    echo "Repository URL being passed to configure_auto.sh: $repository_url"
    
    # Log in to Docker registry first
    echo "🔐 Logging into Docker registry..."
    docker login "$repository_url" || {
        echo "❌ Docker login failed. Please check your Snowflake credentials."
        exit 1
    }
    
    # Call the non-interactive configure script with repository URL as argument
    ./configure_auto.sh "$repository_url"

    # Check if configure_auto.sh succeeded
    if [ $? -ne 0 ]; then
        echo "❌ Error: configure_auto.sh failed. Please check the output above."
        exit 1
    fi
    
    # Verify images were actually pushed
    echo "🔍 Verifying images were pushed successfully..."
    sleep 5  # Wait a moment for images to be available
    new_images_status=$(check_images_exist)
    
    if [ "$new_images_status" -ge "2" ]; then
        echo "✅ All images successfully built and pushed!"
    else
        echo "⚠️  Warning: Not all images were found. Found: $new_images_status, Expected: 2+"
        echo "Continuing anyway, but deployment might fail..."
    fi
fi

echo "📦 Step 4: Checking if application files need to be uploaded..."

# Check if files already uploaded (unless force upload is enabled)
if [ "$FORCE_UPLOAD" = true ]; then
    echo "🔄 Force upload enabled - re-uploading all files..."
    files_status=0  # Force upload by setting status to 0
elif [ "$DEV_MODE" = true ]; then
    echo "🚀 Dev mode: Force re-uploading files for fresh deployment..."
    files_status=0  # Force upload in dev mode for fresh deployment
else
    files_status=$(check_files_uploaded)
    echo "Found $files_status manifest files in stage"
fi

if [ "$files_status" -ge "1" ] && [ "$FORCE_UPLOAD" = false ] && [ "$DEV_MODE" = false ]; then
    echo "✅ Application files already uploaded, skipping..."
else
    if [ "$FORCE_UPLOAD" = true ]; then
        echo "🔧 Force re-uploading application files..."
    elif [ "$DEV_MODE" = true ]; then
        echo "🔧 Dev mode: Re-uploading application files for fresh deployment..."
    else
        echo "🔧 Uploading application files..."
    fi
    
    # Check if app/src directory exists
    if [ ! -d "app/src" ]; then
        echo "❌ Error: app/src directory not found"
        exit 1
    fi

    # List files to be uploaded
    echo "Files to upload:"
    ls -la app/src/

    # Upload files
    snow sql -q "use role naspcs_role; put file://app/src/* @spcs_app.napp.app_stage auto_compress=false overwrite=true;"

    # Check if upload succeeded
    if [ $? -ne 0 ]; then
        echo "❌ Error: File upload failed. Please check the output above."
        exit 1
    fi
    
    echo "✅ Application files uploaded!"
fi

# Step 5: Deploy (idempotent)
echo "🚀 Step 5: Deploying application..."

# Check if application package already exists
pkg_exists=$(check_app_package_exists)

if [ "$pkg_exists" -ge "1" ] && [ "$DEV_MODE" = false ]; then
    echo "⚠️  Application package already exists. Dropping and recreating to ensure clean state..."
    snow sql -q "use role naspcs_role; drop application package if exists spcs_app_pkg;" || echo "Warning: Could not drop existing application package"
    sleep 2
elif [ "$pkg_exists" -ge "1" ] && [ "$DEV_MODE" = true ]; then
    echo "✅ Application package exists, reusing in dev mode..."
fi

# Check if application already exists
app_exists=$(check_application_exists)

if [ "$app_exists" -ge "1" ] && [ "$DEV_MODE" = false ]; then
    echo "⚠️  Application already exists. Dropping and recreating to ensure clean state..."
    snow sql -q "use role nac; drop application if exists falkordb_app;" || echo "Warning: Could not drop existing application"
    sleep 2
elif [ "$app_exists" -ge "1" ] && [ "$DEV_MODE" = true ]; then
    echo "✅ Application exists, reusing in dev mode..."
fi

# Check if compute pool already exists
pool_exists=$(check_compute_pool_exists)

if [ "$pool_exists" -ge "1" ] && [ "$DEV_MODE" = false ]; then
    echo "⚠️  Compute pool already exists. Dropping and recreating to ensure clean state..."
    snow sql -q "use role accountadmin; drop compute pool if exists pool_nac_containers;" || echo "Warning: Could not drop existing compute pool"
    sleep 2
elif [ "$pool_exists" -ge "1" ] && [ "$DEV_MODE" = true ]; then
    echo "✅ Compute pool exists, reusing in dev mode..."
fi

# In dev mode, check if we can skip deployment entirely
if [ "$DEV_MODE" = true ]; then
    echo ""
    echo "🔍 Dev Mode: Checking if deployment can be skipped..."
    
    # Check current status
    setup_complete=$(check_setup_complete)
    images_exist=$(check_images_exist)
    files_uploaded=$(check_files_uploaded)
    app_exists=$(check_application_exists)
    pool_exists=$(check_compute_pool_exists)
    
    echo "📊 Current Status:"
    echo "   - Setup complete: $setup_complete/1"
    echo "   - Images in repo: $images_exist"
    echo "   - Files uploaded: $files_uploaded"
    echo "   - Application exists: $app_exists/1"
    echo "   - Compute pool exists: $pool_exists/1"
    
    if [ "$setup_complete" -ge "1" ] && [ "$images_exist" -ge "2" ] && [ "$files_uploaded" -ge "1" ] && [ "$app_exists" -ge "1" ] && [ "$pool_exists" -ge "1" ]; then
        echo ""
        echo "🎉 All resources exist! Skipping deployment and jumping to verification..."
        echo ""
        
        # Just verify the app is working
        echo "🧪 Verifying existing application..."
        
        # Check if FalkorDB service is running
        app_status=$(snow sql -q "use role nac; call falkordb_app.app_public.start_app('pool_nac_containers', 'wh_nac');" 2>/dev/null | grep -c "Service started" || echo "0")
        
        if [ "$app_status" -ge "1" ]; then
            echo "✅ FalkorDB application is working!"
        else
            echo "⚠️  FalkorDB service may need to be started. Running deployment to ensure proper state..."
        fi
        
        # Show URLs
        echo ""
        echo "📋 Your FalkorDB Application URLs:"
        snow sql -q "use role nac; call falkordb_app.app_public.app_url();" 2>/dev/null || echo "App URL not ready yet"
        snow sql -q "use role nac; call falkordb_app.app_public.falkordb_browser_url();" 2>/dev/null || echo "Browser URL not ready yet"
        snow sql -q "use role nac; call falkordb_app.app_public.falkordb_endpoint();" 2>/dev/null || echo "Endpoint URL not ready yet"
        
        echo ""
        echo "🚀 Development deployment complete - all resources reused!"
        echo ""
        
        # Skip to the end message
        jump_to_end=true
    else
        echo ""
        echo "📝 Some resources missing, proceeding with deployment..."
    fi
fi

# Run the deployment (unless we're jumping to the end)
if [ "${jump_to_end:-false}" = false ]; then
    echo "🚀 Running deployment..."
    
    # Handle version management before running deploy.sql
    echo "🔄 Managing application package version..."
    
    # Check if version v1_0_0 exists and deregister it if needed
    version_exists=$(snow sql -q "use role naspcs_role; show versions in application package spcs_app_pkg;" 2>/dev/null | grep -c "V1_0_0" || echo "0")
    
    if [ "$version_exists" -gt "0" ]; then
        echo "📋 Version v1_0_0 exists, deregistering for update..."
        snow sql -q "use role naspcs_role; alter application package spcs_app_pkg deregister version v1_0_0;" || echo "Note: Deregister may have failed, continuing..."
    else
        echo "📋 Version v1_0_0 does not exist, will create new..."
    fi
    
    # Now run the main deployment
    snow sql -f scripts/deploy.sql
else
    exit 0
fi

# Check if deployment succeeded
if [ $? -eq 0 ]; then
    echo "✅ Deployment completed successfully!"
else
    echo "❌ Deployment failed. Checking for common issues..."
    
    # Check if all required images exist
    echo "🔍 Checking image repository contents..."
    snow sql -q "use role naspcs_role; show images in image repository spcs_app.napp.img_repo;"
    
    # Check if all required files exist in stage
    echo "🔍 Checking stage contents..."
    snow sql -q "use role naspcs_role; list @spcs_app.napp.app_stage;"
    
    exit 1
fi

echo ""
echo "🎉 FalkorDB App deployment completed successfully!"
echo ""
echo "📝 Your FalkorDB application is now deployed and ready to use."
echo "   Access URLs are displayed above for your graph database interfaces."
echo ""
echo "✅ FalkorDB Configuration: Automatic"
echo "   The FalkorDB container automatically configures itself for the SPCS environment."
echo "   No manual configuration required!"
echo ""
echo "🔧 Useful commands for managing your FalkorDB deployment:"
echo "   - Check application status: snow sql -q \"use role nac; show applications;\""
echo "   - Get app URL: snow sql -q \"use role nac; call falkordb_app.app_public.app_url();\""
echo "   - Get FalkorDB Browser URL: snow sql -q \"use role nac; call falkordb_app.app_public.falkordb_browser_url();\""
echo "   - Get FalkorDB endpoint: snow sql -q \"use role nac; call falkordb_app.app_public.falkordb_endpoint();\""
echo "   - Check compute pool: snow sql -q \"use role accountadmin; show compute pools;\""
echo ""
echo "🧹 To clean up all resources later, run:"
echo "   snow sql -f scripts/cleanup.sql"
echo ""
echo "🔄 To re-deploy this application safely (idempotent):"
echo "   ./deploy_falkordb_app.sh"
echo ""
echo "🔧 Deployment options:"
echo "   ./deploy_falkordb_app.sh -d          # Development mode (fast: reuse images)"
echo "   ./deploy_falkordb_app.sh -f          # Force rebuild images"
echo "   ./deploy_falkordb_app.sh -u          # Force re-upload files"
echo "   ./deploy_falkordb_app.sh -f -u       # Force rebuild and re-upload"
echo "   ./deploy_falkordb_app.sh --help      # Show all options"
echo ""
echo "💡 Development tip: Use -d flag for fastest iteration during development!"
echo ""
echo "📊 Next Step: Upload Consumer Data for Graph Analysis"
echo "======================================================"
echo ""
echo "To load sample social network data into your FalkorDB application:"
echo ""
echo "1. 📁 Review the sample data files:"
echo "   - consumer/src/social_nodes_data.csv      # Person nodes with labels"
echo "   - consumer/src/social_relationships.csv   # Friend relationships"
echo ""
echo "2. 🚀 Upload consumer data to your FalkorDB app:"
echo "   ./upload_consumer_data.sh"
echo ""
echo "3. 🧪 Test the consumer data integration:"
echo "   # Use the new load_graph procedure:"
echo "   snow sql -q \"use role nac; call falkordb_app.app_public.load_graph('my_social_graph', 'nac_consumer_data.social_network.social_nodes', 'nac_consumer_data.social_network.social_relationships');\""
echo ""
echo "   # Direct data access:"
echo "   snow sql -q \"use role nac; use database nac_consumer_data; select count(*) as nodes from social_network.social_nodes;\""
echo "   snow sql -q \"use role nac; use database nac_consumer_data; select count(*) as relations from social_network.social_relationships;\""
echo ""
echo "📝 Consumer Data Format:"
echo "   - Nodes: name (unique), node_label"
echo "   - Relationships: from_name, to_name, relationship_type"
echo ""
echo "💡 You can modify the CSV files to add your own data before running upload_consumer_data.sh"
