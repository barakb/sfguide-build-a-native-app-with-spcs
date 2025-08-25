#!/bin/bash

# Consumer Data Upload Script for FalkorDB Native App
# This script uploads social network data as consumer tables and provides references to the running app
# Usage: ./upload_consumer_data.sh

set -e

echo "🚀 FalkorDB Consumer Data Upload Script"
echo "======================================="
echo ""

# Step 1: Create Consumer Database and Schema
echo "📋 Step 1: Setting up consumer database and schema..."

snow sql -q "
use role nac;

-- Create consumer database if it doesn't exist
create database if not exists nac_consumer_data;
use database nac_consumer_data;

-- Create schema for social network data
create schema if not exists social_network;
use schema social_network;

select 'Consumer database and schema created successfully' as status;
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create consumer database and schema"
    exit 1
fi

echo "✅ Consumer database and schema ready!"
echo ""

# Step 2: Create Tables for Nodes and Relationships
echo "📊 Step 2: Creating tables for social network data..."

snow sql -q "
use role nac;
use database nac_consumer_data;
use schema social_network;

-- Create nodes table
create or replace table social_nodes (
    name varchar(100),
    node_label varchar(50)
);

-- Create relationships table  
create or replace table social_relationships (
    from_name varchar(100),
    to_name varchar(100),
    relationship_type varchar(50)
);

select 'Tables created successfully' as status;
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create tables"
    exit 1
fi

echo "✅ Tables created successfully!"
echo ""

# Step 3: Upload CSV Data
echo "📁 Step 3: Uploading CSV data..."

# Check if CSV files exist
if [ ! -f "consumer/src/social_nodes_data.csv" ]; then
    echo "❌ Error: consumer/src/social_nodes_data.csv not found"
    exit 1
fi

if [ ! -f "consumer/src/social_relationships.csv" ]; then
    echo "❌ Error: consumer/src/social_relationships.csv not found"
    exit 1
fi

# Create a temporary stage for data upload
snow sql -q "
use role nac;
use database nac_consumer_data;
use schema social_network;

-- Create temporary stage for CSV upload
create or replace stage csv_upload_stage;

select 'Upload stage created' as status;
"

# Upload CSV files to stage
echo "📤 Uploading nodes data..."
snow sql -q "
use role nac;
use database nac_consumer_data;
use schema social_network;

put file://consumer/src/social_nodes_data.csv @csv_upload_stage auto_compress=false overwrite=true;
"

echo "📤 Uploading relationships data..."
snow sql -q "
use role nac;
use database nac_consumer_data;
use schema social_network;

put file://consumer/src/social_relationships.csv @csv_upload_stage auto_compress=false overwrite=true;
"

# Load data into tables
echo "📋 Loading data into tables..."
snow sql -q "
use role nac;
use database nac_consumer_data;
use schema social_network;

-- Load nodes data
copy into social_nodes
from @csv_upload_stage/social_nodes_data.csv
file_format = (type = csv field_delimiter = ',' skip_header = 1 field_optionally_enclosed_by = '\"');

-- Load relationships data
copy into social_relationships  
from @csv_upload_stage/social_relationships.csv
file_format = (type = csv field_delimiter = ',' skip_header = 1 field_optionally_enclosed_by = '\"');

-- Show loaded data counts
select 'Nodes loaded: ' || count(*) as nodes_status from social_nodes;
select 'Relationships loaded: ' || count(*) as relationships_status from social_relationships;
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to upload and load CSV data"
    exit 1
fi

echo "✅ CSV data uploaded and loaded successfully!"
echo ""

# Step 4: Grant Permissions and Create References
echo "🔐 Step 4: Setting up permissions and references..."

snow sql -q "
use role nac;
use database nac_consumer_data;
use schema social_network;

-- Grant access to the application
grant usage on database nac_consumer_data to application falkordb_app;
grant usage on schema social_network to application falkordb_app;
grant select on table social_nodes to application falkordb_app;
grant select on table social_relationships to application falkordb_app;

select 'Permissions granted to FalkorDB app' as status;
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to grant permissions"
    exit 1
fi

echo "✅ Permissions configured successfully!"
echo ""

# Step 5: Test Consumer Data Access
echo "🧪 Step 5: Testing consumer data access..."

echo "Testing data upload success..."
snow sql -q "
use role nac;
use database nac_consumer_data;
use schema social_network;

-- Show data counts
select 'Nodes loaded: ' || count(*) as status from social_nodes;
select 'Relationships loaded: ' || count(*) as status from social_relationships;

-- Show sample data
select 'Sample nodes:' as info;
select * from social_nodes limit 5;

select 'Sample relationships:' as info;
select * from social_relationships limit 5;
"

echo ""
echo "🎉 Consumer Data Upload Completed Successfully!"
echo "=============================================="
echo ""
echo "📊 Your social network data has been uploaded and is ready for use:"
echo ""
echo "📋 Consumer Database: nac_consumer_data.social_network"
echo "   - social_nodes table: Contains person nodes with labels (name, node_label)"
echo "   - social_relationships table: Contains friendship relationships"
echo ""
echo "� The FalkorDB application has been granted access to your consumer data."
echo "   You can now access this data from within FalkorDB or create custom procedures"
echo "   to load it into your graph database."
echo ""
echo "💡 Direct Access Examples:"
echo "   # Access nodes data:"
echo "   snow sql -q \"use role nac; use database nac_consumer_data; select * from social_network.social_nodes;\""
echo ""
echo "   # Access relationships data:"
echo "   snow sql -q \"use role nac; use database nac_consumer_data; select * from social_network.social_relationships;\""
echo ""
echo "🔧 Integration with FalkorDB:"
echo "   Your FalkorDB application can access this data using REFERENCE() functions"
echo "   in custom procedures you create for loading data into your graph."
echo ""
echo "🔄 To reload data (if CSV files change):"
echo "   ./upload_consumer_data.sh"
echo ""
echo "🧹 To clean up consumer data:"
echo "   snow sql -q \"use role nac; drop database if exists nac_consumer_data;\""
