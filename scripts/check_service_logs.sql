-- Scr-- Get logs from FalkorDB container
select system$get_service_logs('falkordb_app.app_public.st_spcs', 0, 'falkordb-server') as falkordb_logs;t to check SPCS service status and logs
use role nac;

-- Check service status
select system$get_service_status('falkordb_app.app_public.st_spcs') as service_status;

-- Get logs for FalkorDB container
select system$get_service_logs('falkordb_app.app_public.st_spcs', 0, 'eap-falkordb') as falkordb_logs;

-- Show all services
show services in application falkordb_app;

-- Describe the service
describe service falkordb_app.app_public.st_spcs;
