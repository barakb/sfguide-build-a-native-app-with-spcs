--Cleanup Script - Run this to clean up all resources created during the lab
--This script removes all applications, compute pools, databases, and roles

--Step 1 - Clean Up Consumer Objects
use role nac;
drop application if exists falkordb_app;
drop warehouse if exists wh_nac;
drop database if exists nac_test;

--Step 2 - Clean Up Compute Pool (as admin)
use role accountadmin;
drop compute pool if exists pool_nac_containers;

--Step 3 - Clean Up Provider Objects
use role naspcs_role;
drop application package if exists spcs_app_pkg;
drop database if exists spcs_app;
drop warehouse if exists wh_nap;

--Step 4 - Clean Up Roles (as admin)
use role accountadmin;
drop role if exists naspcs_role;
drop role if exists nac;
