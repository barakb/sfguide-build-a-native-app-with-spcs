#!/bin/bash

# Consumer Data Upload Script for FalkorDB Native App
# This script uploads social network data and grants permissions to existing FalkorDB app
# Usage: ./upload_consumer_data.sh

set -e

echo "🚀 FalkorDB Consumer Data Upload Script"
echo "📊 Uploading CSV data and granting permissions to existing app"
echo "=============================================================="
echo ""

# Step 1: Create Consumer Database and Upload Data
echo "📋 Step 1: Setting up consumer database and uploading data..."

snow sql -q "
use role nac;

-- Create consumer database if it doesn't exist and ensure proper ownership
create database if not exists nac_consumer_data;

-- Grant necessary privileges to NAC role for database operations
use role accountadmin;
grant ownership on database nac_consumer_data to role nac;
grant all privileges on database nac_consumer_data to role nac;

use role nac;
use database nac_consumer_data;

-- Create schema for social network data
create schema if not exists social_network;

-- Grant ownership on schema as well
use role accountadmin;
grant ownership on schema nac_consumer_data.social_network to role nac;
grant all privileges on schema nac_consumer_data.social_network to role nac;

use role nac;
use database nac_consumer_data;
use schema social_network;

-- Create stage for file uploads
create stage if not exists csv_stage;

-- Create tables
create or replace table social_nodes (
    name VARCHAR(100),
    node_label VARCHAR(50)
);

create or replace table social_relationships (
    from_name VARCHAR(100),
    to_name VARCHAR(100),
    relationship_type VARCHAR(50)
);

select 'Database setup complete' as status;
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create consumer database and schema"
    exit 1
fi

echo "✅ Consumer database and schema ready!"
echo ""

# Step 2: Upload CSV files
echo "📤 Step 2: Uploading CSV files..."

# Check if CSV files exist
if [ ! -f "consumer/src/social_nodes_data.csv" ]; then
    echo "❌ Error: consumer/src/social_nodes_data.csv not found"
    exit 1
fi

if [ ! -f "consumer/src/social_relationships.csv" ]; then
    echo "❌ Error: consumer/src/social_relationships.csv not found"
    exit 1
fi

echo "📁 Found CSV files:"
echo "   - social_nodes_data.csv ($(wc -l < consumer/src/social_nodes_data.csv) lines)"
echo "   - social_relationships.csv ($(wc -l < consumer/src/social_relationships.csv) lines)"
echo ""

snow sql -q "
use role nac;
use database nac_consumer_data;
use schema social_network;

-- Upload CSV files
put file://consumer/src/social_nodes_data.csv @csv_stage auto_compress=false overwrite=true;
put file://consumer/src/social_relationships.csv @csv_stage auto_compress=false overwrite=true;

-- Load data into tables
copy into social_nodes
from @csv_stage/social_nodes_data.csv
file_format = (type = csv field_optionally_enclosed_by = '\"' skip_header = 1);

copy into social_relationships  
from @csv_stage/social_relationships.csv
file_format = (type = csv field_optionally_enclosed_by = '\"' skip_header = 1);

-- Check loaded data
select 'Nodes loaded: ' || count(*) as nodes_status from social_nodes;
select 'Relationships loaded: ' || count(*) as relationships_status from social_relationships;
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to upload CSV data"
    exit 1
fi

echo "✅ CSV data uploaded successfully!"
echo ""

# Step 3: Grant permissions to existing app
echo "🔑 Step 3: Granting permissions to existing FalkorDB app..."

snow sql -q "
use role nac;

-- Grant permissions to the existing application
grant usage on database nac_consumer_data to application falkordb_app;
grant usage on schema nac_consumer_data.social_network to application falkordb_app;
grant select on table nac_consumer_data.social_network.social_nodes to application falkordb_app;
grant select on table nac_consumer_data.social_network.social_relationships to application falkordb_app;

select 'Permissions granted to FalkorDB app' as status;
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to grant permissions to FalkorDB app"
    exit 1
fi

echo "✅ Permissions granted successfully!"
echo ""

# Step 4: Test the integration
echo "🧪 Step 4: Testing the consumer data integration..."

test_result=$(snow sql -q "
use role nac;
call falkordb_app.app_public.load_graph('social', 'nac_consumer_data.social_network.social_nodes', 'nac_consumer_data.social_network.social_relationships');
" 2>/dev/null | grep -E "Graph:|nodes|relations" || echo "Test query failed")

if [[ "$test_result" == *"Graph:"* ]]; then
    echo "✅ Integration test successful!"
    echo "📊 Result: $test_result"
else
    echo "⚠️  Integration test may have failed, but data and permissions are set up."
    echo "   You can test manually with the command below."
fi

echo ""
echo "🎉 Consumer data upload complete!"
echo ""
echo "📊 Summary:"
echo "   ✅ Consumer database created: nac_consumer_data"
echo "   ✅ Social network schema created: social_network"
echo "   ✅ Tables created: social_nodes, social_relationships"
echo "   ✅ CSV data uploaded and loaded"
echo "   ✅ Permissions granted to FalkorDB app"
echo ""
echo "🔧 Test the integration manually with:"
echo "   snow sql -q \"use role nac; call falkordb_app.app_public.load_graph('social', 'nac_consumer_data.social_network.social_nodes', 'nac_consumer_data.social_network.social_relationships');\""
echo ""
echo "🔍 Check your data with:"
echo "   snow sql -q \"use role nac; select count(*) from nac_consumer_data.social_network.social_nodes;\""
echo "   snow sql -q \"use role nac; select count(*) from nac_consumer_data.social_network.social_relationships;\""
echo ""
echo "🌐 Access your FalkorDB app URLs:"
echo "   snow sql -q \"use role nac; call falkordb_app.app_public.app_url();\""
echo "   snow sql -q \"use role nac; call falkordb_app.app_public.falkordb_browser_url();\""
echo ""
