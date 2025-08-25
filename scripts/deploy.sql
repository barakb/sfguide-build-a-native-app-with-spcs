--Deploy Script - Run this after setup.sql and after building/uploading images and app files
--This script creates and deploys the SPCS Native App

--Step 1 - Create Application Package and Grant Consumer Role Privileges
--after we've uploaded all of the images and files for the native app we need to create our native app package
--after creating the package we'll add a version to it using all of the files upload to our spcs_app database
use role naspcs_role;
create application package if not exists spcs_app_pkg;

-- Drop existing version if it exists and recreate with latest files
-- Note: We need to drop the application first, then deregister and register the version
use role nac;
drop application if exists falkordb_app;

use role naspcs_role;
-- Show existing versions first
show versions in application package spcs_app_pkg;

-- Always use the same fixed version: v1_0_0
-- Register version with latest files (will fail if version already exists, which is expected)
alter application package spcs_app_pkg register version v1_0_0 using @spcs_app.napp.app_stage;
grant install, develop on application package spcs_app_pkg to role nac;

--Step 2 - Install Native App
--at this point we can switch back to our consumer role and create the application in our account using the application package
--this is simulating the experience of what would otherwise be the consumer installing the app in a separate account
use role nac;
drop application if exists falkordb_app;

-- Create the app instance using the hardcoded version
create application falkordb_app
from application package spcs_app_pkg
using version v1_0_0;

--Step 3 - Create Compute Pool for Container Services (Admin)
--as admin, create a compute pool that supports container services
--using cpu_x64_s to provide more CPU capacity for containers
use role accountadmin;

--drop existing pool if it exists
drop compute pool if exists pool_nac_containers;

create compute pool pool_nac_containers
    min_nodes = 1 
    max_nodes = 1
    instance_family = cpu_x64_s
    auto_resume = true;

--grant usage to the NAC role and application
grant usage on compute pool pool_nac_containers to role nac;
grant usage on compute pool pool_nac_containers to application falkordb_app;

--switch back to NAC role for remaining operations
use role nac;
grant usage on warehouse wh_nac to application falkordb_app;
grant bind service endpoint on account to application falkordb_app;

--Step 4 - Start App Service
--now using the dedicated container services compute pool
call falkordb_app.app_public.start_app('pool_nac_containers', 'wh_nac');

--Step 5 - Get Application URLs
--it takes a few minutes to get the app up and running but you can use the following function to find the app url when it is fully deployed
call falkordb_app.app_public.app_url();

--get FalkorDB endpoints
call falkordb_app.app_public.falkordb_browser_url();

--Step 6 - FalkorDB Configuration Instructions
--display instructions for FalkorDB NEXTAUTH_URL configuration
select '=== IMPORTANT: FalkorDB Configuration Required ===' as notice;
select 'The FalkorDB HTTP URL above needs to be configured as NEXTAUTH_URL' as instruction
union all
select 'in the falkordb.yaml file under the eap-falkordb container env section.' as instruction
union all
select 'Then rebuild and redeploy the application for FalkorDB to work correctly.' as instruction;
call falkordb_app.app_public.falkordb_endpoint();
