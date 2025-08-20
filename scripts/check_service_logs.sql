-- Script to check SPCS service status and logs
use role nac;

-- Check service status
select system$get_service_status('fullstack_app.app_public.st_spcs') as service_status;

-- Get logs for FalkorDB container
select system$get_service_logs('fullstack_app.app_public.st_spcs', 0, 'eap-falkordb') as falkordb_logs;

-- Show all services
show services in application fullstack_app;

-- Describe the service
describe service fullstack_app.app_public.st_spcs;
